document.addEventListener('turbo:load', function() {
  // Only run this code if we're on a page that has the share modal
  // This prevents errors on pages like the PDF editor that don't have these elements
  if (document.getElementById('share-modal')) {
    const shareButton = document.getElementById('share-button-modal-trigger');
    const shareModal = document.getElementById('share-modal');

    if (shareButton && shareModal) {
      shareButton.addEventListener('click', () => {
        shareModal.classList.remove('hidden');
      });

      const closeModalButton = shareModal.querySelector('.close-modal');
      if (closeModalButton) {
        closeModalButton.addEventListener('click', () => {
          shareModal.classList.add('hidden');
        });
      }
    }
  }
});
