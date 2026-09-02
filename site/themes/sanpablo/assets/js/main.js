(function () {
  'use strict';

  // Sticky header scroll detection
  const header = document.querySelector('.site-header');
  if (header) {
    let ticking = false;
    function updateHeader() {
      if (window.scrollY > 10) {
        header.classList.add('is-scrolled');
      } else {
        header.classList.remove('is-scrolled');
      }
      ticking = false;
    }
    window.addEventListener('scroll', function () {
      if (!ticking) {
        window.requestAnimationFrame(updateHeader);
        ticking = true;
      }
    });
  }

  const navToggle = document.querySelector('.nav-toggle');
  const mainNav = document.getElementById('main-nav');

  if (navToggle && mainNav) {
    navToggle.addEventListener('click', function () {
      const isOpen = mainNav.classList.toggle('is-open');
      navToggle.setAttribute('aria-expanded', String(isOpen));
    });

    // Close nav when clicking a link (mobile)
    mainNav.querySelectorAll('.nav-link').forEach(function (link) {
      link.addEventListener('click', function () {
        mainNav.classList.remove('is-open');
        navToggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  // Keep the summer timetable visible until the changeover date in Madrid.
  const schedulesBefore = document.querySelectorAll('[data-schedule-before]');
  const schedulesFrom = document.querySelectorAll('[data-schedule-from]');
  if (schedulesBefore.length || schedulesFrom.length) {
    const madridDateParts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Madrid',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }).formatToParts(new Date());
    const datePart = function (type) {
      return madridDateParts.find(function (part) { return part.type === type; }).value;
    };
    const madridDate = datePart('year') + '-' + datePart('month') + '-' + datePart('day');
    const newScheduleIsActive = madridDate >= '2026-09-06';

    schedulesBefore.forEach(function (schedule) {
      schedule.hidden = newScheduleIsActive;
    });
    schedulesFrom.forEach(function (schedule) {
      schedule.hidden = !newScheduleIsActive;
    });
  }

  const slides = document.querySelectorAll('.home-slide');
  if (slides.length > 1 && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    let activeSlide = 0;
    window.setInterval(function () {
      slides[activeSlide].classList.remove('is-active');
      activeSlide = (activeSlide + 1) % slides.length;
      slides[activeSlide].classList.add('is-active');
    }, 5000);
  }
})();
