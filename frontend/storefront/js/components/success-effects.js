(function initSuccessEffects() {
  'use strict';

  var successPanel = document.querySelector('.checkoutSuccess');
  if (!successPanel) return;

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    successPanel.classList.add('isReducedMotion');
    return;
  }

  var colors = [
    'var(--yc-success)',
    'var(--yc-sage-action)',
    'var(--yc-cta)',
    'var(--yc-warning)'
  ];
  var particleCount = 36;

  for (var index = 0; index < particleCount; index += 1) {
    window.setTimeout(function createConfettiParticle() {
      var particle = document.createElement('span');
      var size = Math.random() * 6 + 6;
      var duration = Math.random() * 2 + 2.5;
      var delay = Math.random() * 0.4;

      particle.className = 'confettiParticle';
      particle.setAttribute('aria-hidden', 'true');
      particle.style.setProperty('--confetti-left', Math.random() * 100 + '%');
      particle.style.setProperty('--confetti-size', size + 'px');
      particle.style.setProperty('--confetti-color', colors[Math.floor(Math.random() * colors.length)]);
      particle.style.setProperty('--confetti-radius', Math.random() > 0.5 ? '999px' : '2px');
      particle.style.setProperty('--confetti-delay', delay + 's');
      particle.style.setProperty('--confetti-duration', duration + 's');
      document.body.appendChild(particle);

      window.setTimeout(function removeConfettiParticle() {
        particle.remove();
      }, (duration + delay + 0.5) * 1000);
    }, index * 30);
  }
})();
