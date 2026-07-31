// ==========================================
// MINIMAL APP.JS - Tanpa Import Statement
// ==========================================

// User Dropdown Toggle
window.toggleUserDropdown = function(button) {
  var dropdown = button.parentElement;
  var menu = dropdown.querySelector('.user-dropdown-menu');
  var arrow = button.querySelector('.arrow');
  
  if (menu && menu.classList.contains('show')) {
    menu.classList.remove('show');
    button.classList.remove('active');
    if (arrow) arrow.textContent = '▸';
    document.body.classList.remove('dropdown-open');
  } else if (menu) {
    var allMenus = document.querySelectorAll('.user-dropdown-menu.show');
    for (var i = 0; i < allMenus.length; i++) {
      allMenus[i].classList.remove('show');
      var btn = allMenus[i].parentElement.querySelector('.user-dropdown-toggle');
      if (btn) btn.classList.remove('active');
      var otherArrow = allMenus[i].parentElement.querySelector('.arrow');
      if (otherArrow) otherArrow.textContent = '▸';
    }
    document.body.classList.remove('dropdown-open');
    
    menu.classList.add('show');
    button.classList.add('active');
    if (arrow) arrow.textContent = '▾';
    document.body.classList.add('dropdown-open');
  }
}

// Close dropdown when clicking outside
document.addEventListener('click', function(e) {
  if (!e.target.closest('.user-dropdown')) {
    var allMenus = document.querySelectorAll('.user-dropdown-menu.show');
    for (var i = 0; i < allMenus.length; i++) {
      allMenus[i].classList.remove('show');
      var btn = allMenus[i].parentElement.querySelector('.user-dropdown-toggle');
      if (btn) btn.classList.remove('active');
      var arrow = allMenus[i].parentElement.querySelector('.arrow');
      if (arrow) arrow.textContent = '▸';
    }
    document.body.classList.remove('dropdown-open');
  }
});

// Auto-hide flash messages
document.addEventListener('DOMContentLoaded', function() {
  var flashMessages = document.querySelectorAll('.flash-message');
  for (var i = 0; i < flashMessages.length; i++) {
    (function(msg) {
      setTimeout(function() {
        msg.classList.add('fade-out');
        setTimeout(function() {
          if (msg.parentNode) {
            msg.parentNode.removeChild(msg);
          }
        }, 300);
      }, 1500);
    })(flashMessages[i]);
  }
});