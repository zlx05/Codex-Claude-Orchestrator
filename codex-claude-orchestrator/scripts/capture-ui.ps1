param(
    [string]$ProjectRoot = ".",
    [string]$Url,
    [string]$HtmlPath,
    [int]$Round = 1,
    [string]$RequestId = "",
    [string]$BrowserPath = ""
)

$ErrorActionPreference = "Stop"

$skillRoot = (Resolve-Path -LiteralPath $PSScriptRoot\..).Path
$projectRootPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $projectRootPath

function Get-TaskRoot {
    param([string]$RequestId)
    if ([string]::IsNullOrWhiteSpace($RequestId)) {
        if (Test-Path -LiteralPath "task/CURRENT.md") {
            $current = Get-Content -LiteralPath "task/CURRENT.md" -Raw -Encoding UTF8
            $match = [regex]::Match($current, "(?m)^RequestId:\s*(.+?)\s*$")
            if ($match.Success) {
                return "task/requests/$($match.Groups[1].Value.Trim())"
            }
        }
        return "task"
    }
    return "task/requests/$RequestId"
}

if (-not $Url) {
    if (-not $HtmlPath) {
        $HtmlPath = "demo/index.html"
    }
    $resolvedHtml = (Resolve-Path -LiteralPath $HtmlPath).Path
    $Url = "file:///" + ($resolvedHtml -replace "\\", "/")
}

if (-not $BrowserPath) {
    $browserCandidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe"
    )
    $BrowserPath = $browserCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $BrowserPath -or -not (Test-Path -LiteralPath $BrowserPath)) {
    throw "No Chrome or Edge executable found. Pass -BrowserPath <path-to-chrome-or-edge>."
}

$taskRoot = Get-TaskRoot -RequestId $RequestId
$artifactDir = "$taskRoot/artifacts/round-$Round"
New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

$nodeScript = @'
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const browserPath = process.env.CAPTURE_BROWSER;
const url = process.env.CAPTURE_URL;
const outDir = path.resolve(process.env.CAPTURE_OUT);
fs.mkdirSync(outDir, { recursive: true });

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function getJson(targetUrl) {
  return new Promise((resolve, reject) => {
    http.get(targetUrl, res => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', reject);
  });
}

async function connect(wsUrl) {
  if (typeof WebSocket === 'undefined') {
    throw new Error('This script requires Node.js with global WebSocket support. Use Node 20+ or pass UI validation manually.');
  }

  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });

  let nextId = 0;
  const pending = new Map();

  ws.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (!message.id || !pending.has(message.id)) {
      return;
    }
    const waiter = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) {
      waiter.reject(new Error(JSON.stringify(message.error)));
    } else {
      waiter.resolve(message.result || {});
    }
  });

  return {
    send(method, params = {}) {
      const id = ++nextId;
      ws.send(JSON.stringify({ id, method, params }));
      return new Promise((resolve, reject) => {
        pending.set(id, { resolve, reject });
      });
    },
    close() {
      ws.close();
    }
  };
}

async function runViewport(name, width, height, port) {
  const profileDir = path.resolve(outDir, `browser-profile-${name}`);
  const browser = spawn(browserPath, [
    '--headless=new',
    `--remote-debugging-port=${port}`,
    '--disable-gpu',
    '--hide-scrollbars',
    '--allow-file-access-from-files',
    `--window-size=${width},${height}`,
    `--user-data-dir=${profileDir}`,
    'about:blank'
  ], { stdio: 'ignore' });

  try {
    await delay(1200);
    const tabs = await getJson(`http://127.0.0.1:${port}/json`);
    const tab = tabs.find(item => item.type === 'page') || tabs[0];
    if (!tab || !tab.webSocketDebuggerUrl) {
      throw new Error('Could not find a debuggable page target.');
    }

    const cdp = await connect(tab.webSocketDebuggerUrl);
    try {
      await cdp.send('Page.enable');
      await cdp.send('Runtime.enable');
      await cdp.send('Log.enable');
      await cdp.send('Emulation.setDeviceMetricsOverride', {
        width,
        height,
        deviceScaleFactor: 1,
        mobile: name === 'mobile'
      });
      await cdp.send('Page.navigate', { url });
      await delay(1600);

      const before = await cdp.send('Runtime.evaluate', {
        expression: `(() => {
          const interactive = document.querySelector('button, [role="button"], a[href], input, select, textarea');
          const interactiveRect = interactive ? interactive.getBoundingClientRect() : null;
          const bodyText = document.body ? document.body.innerText.trim() : '';
          return {
            title: document.title,
            innerWidth,
            innerHeight,
            docScrollWidth: document.documentElement.scrollWidth,
            bodyScrollWidth: document.body.scrollWidth,
            bodyTextLength: bodyText.length,
            hasVisibleText: bodyText.length > 0,
            interactiveVisible: !!interactive,
            interactiveRect: interactiveRect && {
              x: interactiveRect.x,
              y: interactiveRect.y,
              width: interactiveRect.width,
              height: interactiveRect.height,
              right: interactiveRect.right
            },
            horizontalOverflow: document.documentElement.scrollWidth > innerWidth || document.body.scrollWidth > innerWidth
          };
        })()`,
        returnByValue: true
      });

      const metrics = before.result.value;
      if (metrics.interactiveRect) {
        await cdp.send('Input.dispatchMouseEvent', {
          type: 'mouseMoved',
          x: metrics.interactiveRect.x + metrics.interactiveRect.width * 0.5,
          y: metrics.interactiveRect.y + metrics.interactiveRect.height * 0.5
        });
        await delay(250);
      }

      const interaction = await cdp.send('Runtime.evaluate', {
        expression: `(() => {
          const interactive = document.querySelector('button, [role="button"], a[href], input, select, textarea');
          return {
            activeElementTag: document.activeElement ? document.activeElement.tagName : null,
            interactiveVisible: !!interactive
          };
        })()`,
        returnByValue: true
      });

      const screenshot = await cdp.send('Page.captureScreenshot', {
        format: 'png',
        captureBeyondViewport: false
      });
      fs.writeFileSync(path.join(outDir, `${name}.png`), Buffer.from(screenshot.data, 'base64'));

      return {
        name,
        viewport: `${width}x${height}`,
        metrics,
        interaction: interaction.result.value
      };
    } finally {
      cdp.close();
    }
  } finally {
    browser.kill();
    await delay(400);
  }
}

(async () => {
  const results = [];
  results.push(await runViewport('desktop', 1440, 900, 9331));
  results.push(await runViewport('mobile', 390, 844, 9332));
  fs.writeFileSync(path.join(outDir, 'ui-check.json'), JSON.stringify(results, null, 2), 'utf8');
  console.log(JSON.stringify(results, null, 2));
})().catch(err => {
  console.error(err);
  process.exit(1);
});
'@

$env:CAPTURE_URL = $Url
$env:CAPTURE_OUT = (Resolve-Path -LiteralPath $artifactDir).Path
$env:CAPTURE_BROWSER = $BrowserPath
$env:CAPTURE_SKILL_ROOT = $skillRoot
$env:CAPTURE_PROJECT_ROOT = $projectRootPath
$nodeScript | node -
