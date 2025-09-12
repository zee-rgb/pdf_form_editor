// Placeholder share-modal.js to prevent 404 errors
document.addEventListener('DOMContentLoaded', function() {
  console.log('Share modal module loaded');
  
  // Only attempt to add listeners if the elements exist
  const shareButton = document.querySelector('.share-button');
  if (shareButton) {
    shareButton.addEventListener('click', function() {
      console.log('Share button clicked');
    });
  }
});
