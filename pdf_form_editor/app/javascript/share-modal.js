document.addEventListener('turbo:load', function() {
  const shareButton = document.getElementById('share-button-modal-trigger'); // Use a more specific ID
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
});
