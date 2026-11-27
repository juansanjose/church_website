const raceStart = Date.parse("2026-12-13T10:00:00+01:00");
const countdown = [
  ["d", 86400],
  ["h", 3600],
  ["m", 60],
  ["s", 1],
].map(([id, unit]) => [document.getElementById(id), unit]);

function updateCountdown() {
  let seconds = Math.max(0, Math.floor((raceStart - Date.now()) / 1000));
  for (const [element, unit] of countdown) {
    element.textContent = String(Math.floor(seconds / unit)).padStart(2, "0");
    seconds %= unit;
  }
}

updateCountdown();
setInterval(updateCountdown, 1000);

if ("IntersectionObserver" in window) {
  document.body.classList.add("reveal");
  const reveal = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add("on");
      reveal.unobserve(entry.target);
    }
  }, { threshold: 0.12 });
  document.querySelectorAll(".rv").forEach((element) => reveal.observe(element));

  const sticky = document.getElementById("sticky");
  const hero = document.querySelector(".hero");
  const registration = document.getElementById("inscripcion");
  const visible = new Set([hero]);
  const stickyVisibility = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) visible.add(entry.target);
      else visible.delete(entry.target);
    }
    sticky.classList.toggle("show", visible.size === 0);
  });
  stickyVisibility.observe(hero);
  stickyVisibility.observe(registration);
}
