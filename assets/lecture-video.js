/* Show paused recordings online; keep the offline book link-only. */
document.querySelectorAll('.lecture-video').forEach(card => {
  if (location.protocol === 'file:' || window.NptelOffline) return;
  const link = card.querySelector('.lecture-video-link');
  const player = card.querySelector('.lecture-video-player');
  link.hidden = true;
  function updatePlayer() {
    if (document.body.classList.contains('mode-slides')) {
      // Remove the player so a hidden video cannot continue playing audio.
      player.replaceChildren();
      player.hidden = true;
    } else if (!player.firstChild) {
      const frame = document.createElement('iframe');
      frame.title = 'Lecture recording';
      frame.src = `https://www.youtube-nocookie.com/embed/${card.dataset.youtubeId}`;
      frame.allow = 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
      frame.allowFullscreen = true;
      frame.referrerPolicy = 'strict-origin-when-cross-origin';
      player.replaceChildren(frame);
      player.hidden = false;
    }
  }
  updatePlayer();
  new MutationObserver(updatePlayer).observe(document.body, {
    attributes: true, attributeFilter: ['class'],
  });
});
