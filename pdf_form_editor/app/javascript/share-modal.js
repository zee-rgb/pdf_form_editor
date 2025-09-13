// Wrap in a try-catch block to prevent any errors from breaking the page
try {
  // Wait until the DOM is fully loaded
  function initShareModal() {
    // Only run this code if we're on a page that has the share modal
    const shareModal = document.getElementById('share-modal');
    if (!shareModal) {
      // No share modal on this page, exit gracefully
      return;
    }
    
    // Now safely look for the button
    const shareButton = document.getElementById('share-button-modal-trigger');
    if (shareButton) {
      shareButton.addEventListener('click', () => {
        shareModal.classList.remove('hidden');
      });
    }

    // Look for close button inside the modal
    const closeModalButton = shareModal.querySelector('.close-modal');
    if (closeModalButton) {
      closeModalButton.addEventListener('click', () => {
        shareModal.classList.add('hidden');
      });
    }
  }

  // Run on initial page load
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    initShareModal();
  } else {
    document.addEventListener('DOMContentLoaded', initShareModal);
  }
  
  // Run again when Turbo navigates to a new page
  document.addEventListener('turbo:load', initShareModal);
  document.addEventListener('turbo:render', initShareModal);
} catch (error) {
  // Silently handle errors to prevent console messages
  console.debug('Share modal initialization skipped:', error);
}
