// ==========================================
// APP.JS - Phoenix LiveView + OJS helpers
// ==========================================

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

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

// ==========================================
// Make a Submission: Details (OJS 3.5 wizard)
// ==========================================
(function () {
  function initRichtextEditors() {
    var editors = document.querySelectorAll('.ojs-richtext[data-target], .rp-richtext[data-target]');

    Array.prototype.forEach.call(editors, function (editor) {
      if (editor.__richtextInit) return;
      editor.__richtextInit = true;

      var targetId = editor.getAttribute('data-target');
      var hidden = document.getElementById(targetId);
      if (!hidden) return;

      var toolbar = document.getElementById(targetId + '-toolbar');
      var buttons = toolbar ? toolbar.querySelectorAll('button[data-cmd]') : [];

      var autosaveKey = editor.getAttribute('data-autosave');
      var draftValue = autosaveKey
        ? window.localStorage.getItem(autosaveKey)
        : null;

      if (autosaveKey && draftValue !== null) {
        hidden.value = draftValue;
      }

      editor.innerHTML = hidden.value || '';

      Array.prototype.forEach.call(buttons, function (btn) {
        btn.addEventListener('mousedown', function (e) {
          e.preventDefault();
        });
      });

      function stateActive(cmd) {
        try {
          if (cmd === 'bold') return document.queryCommandState('bold');
          if (cmd === 'italic') return document.queryCommandState('italic');
          if (cmd === 'superscript') return document.queryCommandState('superscript');
          if (cmd === 'subscript') return document.queryCommandState('subscript');
        } catch (e) {}
        return false;
      }

      function sync() {
        hidden.value = editor.innerHTML;
        if (autosaveKey) {
          try {
            window.localStorage.setItem(autosaveKey, editor.innerHTML);
          } catch (e) {}
        }
        Array.prototype.forEach.call(buttons, function (btn) {
          var cmd = btn.getAttribute('data-cmd');
          btn.classList.toggle('is-active', stateActive(cmd));
        });
      }

      function exec(cmd) {
        editor.focus();
        if (cmd === 'createLink') {
          var url = window.prompt('Enter the link URL:', 'https://');
          if (!url) return;
          document.execCommand('createLink', false, url);
        } else {
          document.execCommand(cmd, false, null);
        }
        sync();
      }

      Array.prototype.forEach.call(buttons, function (btn) {
        btn.addEventListener('click', function () {
          exec(btn.getAttribute('data-cmd'));
        });
      });

      editor.addEventListener('input', sync);
      editor.addEventListener('keyup', sync);
      editor.addEventListener('blur', sync);
      document.addEventListener('selectionchange', sync);

      var form = hidden.form || hidden.closest('form');
      if (form) {
        form.addEventListener('submit', function () {
          sync();
          if (autosaveKey) {
            try {
              window.localStorage.removeItem(autosaveKey);
            } catch (e) {}
          }
        });
      }
    });
  }

  function initOjsDetailsValidation() {
    var form = document.getElementById('submission-details-form');
    if (!form) return;

    var titleInput = document.getElementById('title');
    var editor = document.getElementById('abstract-editor');
    var hidden = document.getElementById('abstract');
    var alertBox = document.getElementById('details-alert');

    var fields = [
      { id: 'title', input: titleInput, field: document.getElementById('title-field') },
      { id: 'abstract', input: editor, field: document.getElementById('abstract-field') }
    ];

    var messages = {
      title: 'A title is required.',
      abstract: 'An abstract is required.'
    };

    function errorEl(id) {
      return form.querySelector('[data-error-for="' + id + '"]');
    }

    function stripTags(html) {
      var div = document.createElement('div');
      div.innerHTML = html || '';
      return (div.textContent || '').replace(/\u00a0/g, ' ').trim();
    }

    function isValid(field) {
      if (field.id === 'title') {
        return String(titleInput.value || '').trim() !== '';
      }
      return stripTags(hidden ? hidden.value : editor.innerHTML) !== '';
    }

    function showError(field, show) {
      var el = errorEl(field.id);
      var box = field.field;
      var inputEl = field.input;
      if (el) el.textContent = show ? messages[field.id] : '';
      if (box) box.classList.toggle('has-error', show);
      if (!inputEl) return show;
      if (field.id === 'abstract') {
        inputEl.classList.toggle('ojs-richtext-error', show);
      } else {
        inputEl.classList.toggle('ojs-input-error', show);
      }
      return show;
    }

    function clearErrors() {
      fields.forEach(function (field) {
        showError(field, false);
      });
      if (alertBox) alertBox.hidden = true;
    }

    function validateAll() {
      var ok = true;
      fields.forEach(function (field) {
        if (showError(field, !isValid(field))) ok = false;
      });
      return ok;
    }

    if (titleInput) titleInput.addEventListener('input', clearErrors);
    if (editor) editor.addEventListener('input', clearErrors);

    form.addEventListener('submit', function (e) {
      if (hidden && editor) hidden.value = editor.innerHTML;
      var ok = validateAll();
      if (alertBox) alertBox.hidden = ok;
      if (!ok) {
        e.preventDefault();
        var firstInvalid = fields.find(function (field) {
          return !isValid(field);
        });
        if (firstInvalid && firstInvalid.input) firstInvalid.input.focus();
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initRichtextEditors();
    initOjsDetailsValidation();
  });
})();

// ==========================================
// File Upload Section: open the file picker
// ==========================================
document.addEventListener('click', function (e) {
  var addBtn = e.target.closest('.ojs-add-file-btn');
  var link = e.target.closest('.ojs-upload-file-link');
  if (addBtn || link) {
    e.preventDefault();
    var input = document.getElementById('file-input');
    if (input) input.click();
    return;
  }
  if (e.target.closest('button, a, input, label')) return;
  var dz = e.target.closest('.ojs-dropzone');
  if (dz) {
    var input = dz.querySelector('input[type="file"]');
    if (input) input.click();
  }
});

// ==========================================
// Confirm Action (workflow decline buttons)
// ==========================================
window.confirmAction = function(message, form) {
  if (window.confirm(message)) {
    form.submit();
  }
};

// ==========================================
// Phoenix LiveSocket
// ==========================================
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
});

topbar.config({ barColors: { 0: "#1E6292" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", function () { topbar.delayedShow(200); });
window.addEventListener("phx:page-loading-stop", function () { topbar.hide(); });

liveSocket.connect();
window.liveSocket = liveSocket;