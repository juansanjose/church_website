---
title: "Formación"
slug: "formacion"
date: "2026-05-15T16:03:28"
lastmod: "2026-06-14T10:00:00"
url: "/formacion/"
page_class: "content--cards"
description: "Grupos de formación de la Parroquia San Pablo de la Cruz."
custom_css: |
  .page--formacion {
    display: block;
  }
  .formacion-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(100%, 15rem), 1fr));
    gap: 1.25rem;
    margin-top: 2rem;
  }
  .formacion-card {
    display: flex;
    flex-direction: column;
    padding: 1.5rem;
    border: 1px solid var(--border);
    border-top: 4px solid var(--card-accent, var(--green));
    border-radius: var(--radius);
    background: var(--bg);
    box-shadow: var(--shadow-sm);
  }
  .formacion-card--infantiles {
    --card-accent: #c9a55c;
  }
  .formacion-card--juveniles {
    --card-accent: #3d6144;
  }
  .formacion-card--universitarios {
    --card-accent: #506b8b;
  }
  .formacion-card--inscripcion {
    --card-accent: #8b5f68;
  }
  .formacion-card__icon {
    display: grid;
    width: 3rem;
    height: 3rem;
    margin-bottom: 1rem;
    place-items: center;
    border-radius: 50%;
    background: color-mix(in srgb, var(--card-accent) 14%, white);
    font-size: 1.5rem;
  }
  .formacion-card h2 {
    margin: 0 0 0.75rem;
    padding: 0;
    border: 0;
    font-size: 1.35rem;
  }
  .formacion-card p {
    margin-bottom: 1.25rem;
    color: var(--text-light);
  }
  .formacion-card a {
    align-self: flex-start;
    margin-top: auto;
    padding: 0.65rem 1.25rem;
    border-radius: var(--radius-pill);
    background: var(--green);
    color: var(--bg);
    font-weight: 600;
    text-decoration: none;
  }
  .formacion-card a:hover,
  .formacion-card a:focus-visible {
    background: var(--green-dark);
    color: var(--bg);
  }
  .formacion-card a:focus-visible {
    outline: 2px solid var(--gold);
    outline-offset: 0.2rem;
  }
---

Grupos de formación para todas las edades en nuestra parroquia.

<div class="formacion-grid">
  <article class="formacion-card formacion-card--infantiles">
    <span class="formacion-card__icon" aria-hidden="true">🧒</span>
    <h2>Infantiles</h2>
    <p>Preparación para la Primera Comunión. Niños de 8 años en adelante.</p>
    <a href="/catequesis/infantiles-primera-comunion/">Acceder</a>
  </article>
  <article class="formacion-card formacion-card--juveniles">
    <span class="formacion-card__icon" aria-hidden="true">🌱</span>
    <h2>Juveniles</h2>
    <p>Grupo de jóvenes Post-Comunión. Convivencias, retiros y formación cristiana.</p>
    <a href="/catequesis/juveniles-post-comunion/">Acceder</a>
  </article>
  <article class="formacion-card formacion-card--universitarios">
    <span class="formacion-card__icon" aria-hidden="true">🎓</span>
    <h2>Universitarios</h2>
    <p>Espacio de encuentro y reflexión para jóvenes universitarios.</p>
    <a href="/catequesis/jovenes-confirmacion/">Acceder</a>
  </article>
  <article class="formacion-card formacion-card--inscripcion">
    <span class="formacion-card__icon" aria-hidden="true">✍️</span>
    <h2>Inscripción</h2>
    <p>Inscríbete en nuestros grupos de formación.</p>
    <a href="/formacion/inscripcion/">Inscripción</a>
  </article>
</div>
