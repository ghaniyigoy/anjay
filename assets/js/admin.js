// assets/js/admin.js
document.addEventListener('DOMContentLoaded', function() {
  const toggles = document.querySelectorAll('.journal-toggle');
  
  toggles.forEach(function(toggle) {
    toggle.addEventListener('click', function() {
      const journalId = this.getAttribute('data-journal-id');
      const subRow = document.getElementById('journal-sub-' + journalId);
      
      if (subRow.style.display === 'none') {
        subRow.style.display = 'table-row';
        this.textContent = '▼';
        this.classList.add('expanded');
      } else {
        subRow.style.display = 'none';
        this.textContent = '▶';
        this.classList.remove('expanded');
      }
    });
  });
});