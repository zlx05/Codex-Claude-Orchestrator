/* === Codex + Claude Orchestrator Demo === */
(function () {
  'use strict';

  /* --- Reduced motion check --- */
  const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  let preferReducedMotion = motionQuery.matches;
  motionQuery.addEventListener('change', function (e) {
    preferReducedMotion = e.matches;
    if (preferReducedMotion) {
      particles.length = 0;
    } else if (particles.length === 0) {
      seedParticles();
    }
  });

  /* --- DOM refs --- */
  const canvas = document.getElementById('particles');
  const ctx = canvas.getContext('2d');

  const hudRound = document.getElementById('hud-round');
  const hudStatus = document.getElementById('hud-status');
  const footerStatus = document.getElementById('footer-status');

  const boardNodes = document.querySelectorAll('.board-node');
  const progressFill = document.getElementById('progress-fill');
  const progressPips = document.querySelectorAll('.pip');

  const inspectorBody = document.getElementById('inspector-body');
  const inspectorBadge = document.getElementById('inspector-badge');

  const gateIcon = document.getElementById('gate-icon');
  const gateDesc = document.getElementById('gate-desc');
  const gateResult = document.getElementById('gate-result');
  const gateBadge = document.getElementById('gate-badge');
  const boardBadge = document.getElementById('board-badge');

  const btnPass = document.getElementById('btn-pass');
  const btnRevise = document.getElementById('btn-revise');

  /* --- Inspector content definitions --- */
  var inspectorContent = {
    plan: {
      title: 'Codex Plans',
      desc: 'Codex receives the user request and writes a precise plan with allowed files, acceptance criteria, and validation commands.',
      meta: ['plan.md', 'context.md', 'allowed files', 'validation'],
    },
    build: {
      title: 'Claude Builds',
      desc: 'Claude reads the plan, implements each item in order, runs validation, and writes a structured execution report.',
      meta: ['execution.md', 'file edits', 'validation run', 'UI evidence'],
    },
    review: {
      title: 'Codex Reviews',
      desc: 'Codex inspects the diff, checks the execution report, validates results, and decides whether to pass or revise.',
      meta: ['diff inspection', 'report audit', 'scope check', 'gate decision'],
    },
    gate: {
      title: 'Review Gate',
      desc: 'Every round ends at the gate. PASS means the task is done. REVISE means Codex writes a new plan and Claude runs again.',
      meta: ['PASS', 'REVISE', 'max iterations'],
    },
  };

  /* --- State --- */
  var state = {
    currentStep: null,
    gateResult: null,
    round: 1,
  };

  /* === Canvas Particles === */
  var particles = [];
  var canvasW = 0;
  var canvasH = 0;
  var mouseX = -100;
  var mouseY = -100;
  var animFrame = null;
  var particleColors = [
    'rgba(74,222,128,0.5)',
    'rgba(56,189,248,0.45)',
    'rgba(250,204,21,0.4)',
    'rgba(34,197,94,0.35)',
    'rgba(186,230,253,0.5)',
    'rgba(254,240,138,0.4)',
  ];

  function resizeCanvas() {
    canvasW = window.innerWidth;
    canvasH = window.innerHeight;
    canvas.width = canvasW;
    canvas.height = canvasH;
  }

  function seedParticles() {
    var count = Math.min(60, Math.floor((canvasW * canvasH) / 18000));
    particles.length = 0;
    for (var i = 0; i < count; i++) {
      particles.push({
        x: Math.random() * canvasW,
        y: Math.random() * canvasH,
        r: 2 + Math.random() * 4,
        vx: (Math.random() - 0.5) * 0.4,
        vy: (Math.random() - 0.5) * 0.3 - 0.2,
        color: particleColors[Math.floor(Math.random() * particleColors.length)],
        opacity: 0.3 + Math.random() * 0.4,
      });
    }
  }

  function drawParticles() {
    if (preferReducedMotion) return;
    ctx.clearRect(0, 0, canvasW, canvasH);

    var mx = mouseX;
    var my = mouseY;

    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];

      var dx = mx - p.x;
      var dy = my - p.y;
      var dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 180 && dist > 0) {
        var force = (180 - dist) / 180;
        p.vx -= (dx / dist) * force * 0.03;
        p.vy -= (dy / dist) * force * 0.03;
      }

      p.vx += (Math.random() - 0.5) * 0.02;
      p.vy += (Math.random() - 0.5) * 0.02;

      p.vx *= 0.999;
      p.vy *= 0.999;

      var speed = Math.sqrt(p.vx * p.vx + p.vy * p.vy);
      if (speed > 0.8) {
        p.vx = (p.vx / speed) * 0.8;
        p.vy = (p.vy / speed) * 0.8;
      }

      p.x += p.vx;
      p.y += p.vy;

      if (p.x < -20) p.x = canvasW + 20;
      if (p.x > canvasW + 20) p.x = -20;
      if (p.y < -20) p.y = canvasH + 20;
      if (p.y > canvasH + 20) p.y = -20;

      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = p.color;
      ctx.globalAlpha = p.opacity;
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  function animateParticles() {
    drawParticles();
    animFrame = requestAnimationFrame(animateParticles);
  }

  /* --- Pointer tracking --- */
  function onPointerMove(e) {
    mouseX = e.clientX;
    mouseY = e.clientY;
  }

  /* === Board tilt effect === */
  var tiltTargets = null;

  function applyTilt(e) {
    if (preferReducedMotion || !tiltTargets) return;
    if (!tiltTargets.length) {
      tiltTargets = document.querySelectorAll('.board-node, .folder-card, .callout-card');
    }
    var mx = e.clientX;
    var my = e.clientY;
    for (var i = 0; i < tiltTargets.length; i++) {
      var el = tiltTargets[i];
      var rect = el.getBoundingClientRect();
      var cx = rect.left + rect.width / 2;
      var cy = rect.top + rect.height / 2;
      var dx = (mx - cx) / (rect.width / 2);
      var dy = (my - cy) / (rect.height / 2);
      dx = Math.max(-1, Math.min(1, dx));
      dy = Math.max(-1, Math.min(1, dy));
      var rotateX = -dy * 2.5;
      var rotateY = dx * 2.5;
      el.style.transform =
        'perspective(600px) rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg)';
    }
  }

  function onTiltPointerMove(e) {
    applyTilt(e);
  }

  /* === Board node interaction === */
  function clearNodeStates() {
    for (var i = 0; i < boardNodes.length; i++) {
      boardNodes[i].classList.remove('active', 'active-pass', 'active-revise');
      boardNodes[i].setAttribute('aria-pressed', 'false');
    }
  }

  function updateProgress(stepIndex) {
    var widthPct = ((stepIndex + 1) / 4) * 100;
    progressFill.style.width = widthPct + '%';
    progressFill.classList.remove('fill-revise');

    for (var i = 0; i < progressPips.length; i++) {
      progressPips[i].classList.remove('pip-done', 'pip-pass', 'pip-revise');
      if (i <= stepIndex) {
        progressPips[i].classList.add('pip-done');
      }
    }
  }

  function selectNode(node) {
    var step = node.getAttribute('data-step');
    if (!step) return;

    clearNodeStates();

    if (step === 'gate' && state.gateResult) {
      node.classList.add(state.gateResult === 'PASS' ? 'active-pass' : 'active-revise');
    } else if (step === 'gate') {
      node.classList.add('active');
    } else {
      node.classList.add('active');
    }
    node.setAttribute('aria-pressed', 'true');

    state.currentStep = step;
    updateInspector(step);
    updateProgress(['plan', 'build', 'review', 'gate'].indexOf(step));

    inspectorBody.classList.add('active');
    inspectorBadge.textContent = step.charAt(0).toUpperCase() + step.slice(1);
  }

  function updateInspector(step) {
    var info = inspectorContent[step];
    if (!info) return;

    var metaHtml = '';
    for (var i = 0; i < info.meta.length; i++) {
      metaHtml += '<span class="detail-chip">' + info.meta[i] + '</span>';
    }

    inspectorBody.innerHTML =
      '<div class="inspector-detail">' +
      '<h3>' +
      info.title +
      '</h3>' +
      '<p>' +
      info.desc +
      '</p>' +
      '<div class="detail-meta">' +
      metaHtml +
      '</div>' +
      '</div>';
  }

  function onNodeClick(e) {
    var node = e.currentTarget;
    selectNode(node);
  }

  function onNodeKeydown(e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      selectNode(e.currentTarget);
    }
  }

  /* === Gate controls === */
  function triggerPass() {
    state.gateResult = 'PASS';
    state.round++;

    hudRound.textContent = state.round;
    hudStatus.textContent = 'PASSED';
    footerStatus.textContent = 'Passed - Task complete';

    clearNodeStates();
    var gateNode = document.querySelector('.board-node-gate');
    if (gateNode) {
      gateNode.classList.add('active-pass');
      gateNode.setAttribute('aria-pressed', 'true');
    }
    if (gateIcon) gateIcon.textContent = 'OK';
    if (gateDesc) gateDesc.textContent = 'Passed - Task complete';
    if (boardBadge) boardBadge.textContent = 'Round ' + state.round + ' ready';

    progressFill.style.width = '100%';
    progressFill.classList.remove('fill-revise');
    for (var i = 0; i < progressPips.length; i++) {
      progressPips[i].classList.add('pip-done');
    }
    var gatePip = document.querySelector('.pip-gate');
    if (gatePip) {
      gatePip.classList.add('pip-pass');
    }

    gateResult.innerHTML =
      '<div class="gate-result-message gate-result-pass">PASS - Task complete. Ready for next request.</div>';
    if (gateBadge) gateBadge.textContent = 'PASSED';

    if (inspectorBadge) inspectorBadge.textContent = 'Gate';
    updateInspector('gate');
    inspectorBody.classList.add('active');

    if (!preferReducedMotion) {
      burstParticles(0, 0, false);
    }
  }

  function triggerRevise() {
    state.gateResult = 'REVISE';
    state.round++;

    hudRound.textContent = state.round;
    hudStatus.textContent = 'REVISING';
    footerStatus.textContent = 'Revising - New plan needed';

    clearNodeStates();
    var gateNode = document.querySelector('.board-node-gate');
    if (gateNode) {
      gateNode.classList.add('active-revise');
      gateNode.setAttribute('aria-pressed', 'true');
    }
    if (gateIcon) gateIcon.textContent = 'R';
    if (gateDesc) gateDesc.textContent = 'Revise - Loop back';
    if (boardBadge) boardBadge.textContent = 'Round ' + state.round + ' active';

    progressFill.style.width = '100%';
    progressFill.classList.add('fill-revise');
    for (var i = 0; i < progressPips.length; i++) {
      progressPips[i].classList.add('pip-done');
    }
    var gatePip = document.querySelector('.pip-gate');
    if (gatePip) {
      gatePip.classList.add('pip-revise');
    }

    gateResult.innerHTML =
      '<div class="gate-result-message gate-result-revise">REVISE - Codex writes a correction plan. Claude runs again.</div>';
    if (gateBadge) gateBadge.textContent = 'REVISE';

    if (inspectorBadge) inspectorBadge.textContent = 'Gate';
    updateInspector('gate');
    inspectorBody.classList.add('active');

    if (!preferReducedMotion) {
      burstParticles(0, 1, false);
    }
  }

  /* --- Particle burst on gate action --- */
  function burstParticles(x, y, pass) {
    var cx = x || canvasW / 2;
    var cy = y || canvasH / 2;
    var burstColors = pass
      ? ['#22c55e', '#4ade80', '#bbf7d0', '#86efac', '#dcfce7']
      : ['#f59e0b', '#fbbf24', '#fef08a', '#facc15', '#fef9c3'];

    var burstCount = 30;
    var burstParticles = [];
    for (var i = 0; i < burstCount; i++) {
      var angle = (Math.PI * 2 * i) / burstCount + (Math.random() - 0.5) * 0.3;
      var speed = 2 + Math.random() * 4;
      burstParticles.push({
        x: cx,
        y: cy,
        r: 2 + Math.random() * 5,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color: burstColors[Math.floor(Math.random() * burstColors.length)],
        opacity: 0.7 + Math.random() * 0.3,
        life: 1,
        decay: 0.012 + Math.random() * 0.025,
      });
    }

    function animateBurst() {
      ctx.clearRect(0, 0, canvasW, canvasH);

      var anyAlive = false;
      for (var j = 0; j < burstParticles.length; j++) {
        var bp = burstParticles[j];
        if (bp.life <= 0) continue;
        anyAlive = true;
        bp.x += bp.vx;
        bp.y += bp.vy;
        bp.vy += 0.03;
        bp.life -= bp.decay;
        ctx.beginPath();
        ctx.arc(bp.x, bp.y, bp.r * bp.life, 0, Math.PI * 2);
        ctx.fillStyle = bp.color;
        ctx.globalAlpha = bp.opacity * bp.life;
        ctx.fill();
      }
      ctx.globalAlpha = 1;

      if (anyAlive) {
        requestAnimationFrame(animateBurst);
      } else {
        drawParticles();
        animFrame = requestAnimationFrame(animateParticles);
      }
    }

    if (!preferReducedMotion) {
      cancelAnimationFrame(animFrame);
      animateBurst();
    }
  }

  /* --- Gate button handlers --- */
  function onPassClick() {
    triggerPass();
  }

  function onReviseClick() {
    triggerRevise();
  }

  function onGateKeydown(e) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      e.currentTarget.click();
    }
  }

  /* === Window resize === */
  function onResize() {
    resizeCanvas();
    if (!preferReducedMotion && particles.length === 0) {
      seedParticles();
    }
  }

  /* === Init === */
  function init() {
    resizeCanvas();

    if (!preferReducedMotion) {
      seedParticles();
      animFrame = requestAnimationFrame(animateParticles);
    }

    document.addEventListener('pointermove', onPointerMove, { passive: true });

    var hero = document.querySelector('.hero');
    var board = document.getElementById('board');
    if (hero) hero.addEventListener('pointermove', onTiltPointerMove, { passive: true });
    if (board) board.addEventListener('pointermove', onTiltPointerMove, { passive: true });

    for (var i = 0; i < boardNodes.length; i++) {
      boardNodes[i].addEventListener('click', onNodeClick);
      boardNodes[i].addEventListener('keydown', onNodeKeydown);
    }

    if (btnPass) {
      btnPass.addEventListener('click', onPassClick);
      btnPass.addEventListener('keydown', onGateKeydown);
    }
    if (btnRevise) {
      btnRevise.addEventListener('click', onReviseClick);
      btnRevise.addEventListener('keydown', onGateKeydown);
    }

    window.addEventListener('resize', onResize, { passive: true });

    /* Auto-select first node for immediate experience */
    var firstNode = document.querySelector('.board-node[data-step="plan"]');
    if (firstNode) {
      setTimeout(function () {
        selectNode(firstNode);
      }, 600);
    }
  }

  /* --- Start --- */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  /* --- Expose gate triggers for potential programmatic use --- */
  window._codexDemo = {
    triggerPass: triggerPass,
    triggerRevise: triggerRevise,
    selectNode: selectNode,
    getState: function () {
      return state;
    },
  };
})();
