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
    var editors = document.querySelectorAll(
      '.ojs-richtext[data-target], .rp-richtext[data-target], .enr-richtext[data-target], .prd-richtext[data-target]'
    );

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
// File row three-dot menu (workflow_3_1)
// ==========================================
window.openFileMenu = function(id) {
  var el = document.getElementById(id);
  if (!el) return;
  if (el.classList.contains('wf-open')) {
    el.classList.remove('wf-open');
  } else {
    closeAllFileMenus();
    el.classList.add('wf-open');
  }
};

window.closeFileMenu = function(id) {
  var el = document.getElementById(id);
  if (el) el.classList.remove('wf-open');
};

window.closeAllFileMenus = function() {
  var open = document.querySelectorAll('.wf-file-menu.wf-open');
  Array.prototype.forEach.call(open, function (el) {
    el.classList.remove('wf-open');
  });
};

document.addEventListener('click', function (e) {
  if (!e.target.closest('.wf-file-menu')) {
    window.closeAllFileMenus();
  }
});

// ==========================================
// Edit File slide-in modal (workflow)
// ==========================================
window.openEditFileModal = function(fileId, name) {
  var overlay = document.getElementById('edit-file-overlay');
  var input = document.getElementById('edit-file-name-input');
  var hint = document.getElementById('edit-file-name-hint');
  var idField = document.getElementById('edit-file-id');
  if (input) {
    input.value = name || '';
    input.classList.remove('ef-input-error');
  }
  if (idField) idField.value = fileId || '';
  if (hint) {
    hint.textContent = name ? 'Current file: ' + name : '';
    hint.classList.remove('ef-hint-error');
  }
  if (overlay) overlay.classList.add('ar-open');
};

window.closeEditFileModal = function() {
  var overlay = document.getElementById('edit-file-overlay');
  if (overlay) overlay.classList.remove('ar-open');
};

window.saveEditFile = function() {
  var overlay = document.getElementById('edit-file-overlay');
  var input = document.getElementById('edit-file-name-input');
  var hint = document.getElementById('edit-file-name-hint');
  if (!input) return;

  var name = (input.value || '').trim();
  if (!name) {
    input.classList.add('ef-input-error');
    if (hint) {
      hint.classList.add('ef-hint-error');
      hint.textContent = 'The file name is required.';
    }
    return;
  }

  var submissionId = (document.getElementById('edit-file-submission-id') || {}).value || '';
  var fileId = (document.getElementById('edit-file-id') || {}).value || '';

  fetch('/submission/' + submissionId + '/edit-file', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    },
    body: JSON.stringify({ file_id: fileId, name: name })
  }).then(function(res) {
    return res.json().then(function(data) {
      return { status: res.status, data: data };
    });
  }).then(function(res) {
    if (res.data && res.data.ok) {
      var cell = document.getElementById('submission-file-name-' + fileId);
      if (cell) cell.textContent = res.data.filename;
      if (hint) {
        hint.classList.remove('ef-hint-error');
        hint.textContent = '';
      }
      window.closeEditFileModal();
    } else {
      if (hint) {
        hint.classList.add('ef-hint-error');
        hint.textContent = (res.data && res.data.error) || 'Gagal menyimpan.';
      }
    }
  }).catch(function() {
    if (hint) {
      hint.classList.add('ef-hint-error');
      hint.textContent = 'Gagal menyimpan.';
    }
  });
};

document.addEventListener('click', function (e) {
  var overlay = document.getElementById('edit-file-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('ar-open')) {
    overlay.classList.remove('ar-open');
  }
});

// ==========================================
// Send for Review: Email Notification page
// ==========================================
(function () {
  function initEmailNotification() {
    // Select a template -> populate subject + message body
    var selectors = document.querySelectorAll('[data-enr-template-select]');
    Array.prototype.forEach.call(selectors, function (btn) {
      if (btn.__enrInit) return;
      btn.__enrInit = true;
      btn.addEventListener('click', function () {
        var item = btn.closest('.enr-template-item');
        var allItems = document.querySelectorAll('.enr-template-item.enr-template-selected');
        Array.prototype.forEach.call(allItems, function (el) {
          el.classList.remove('enr-template-selected');
        });
        if (item) item.classList.add('enr-template-selected');

        var subject = btn.getAttribute('data-subject');
        var subjectInput = document.getElementById('enr-subject');
        if (subjectInput) subjectInput.value = subject || '';

        var editor = document.getElementById('enr-message-editor');
        if (editor && subject) {
          var toValue = document.getElementById('enr-to') ? document.getElementById('enr-to').value : 'Author';
          var bodyText = '<p>Dear ' + toValue + ',</p>' +
            '<p>' + subject + '.</p>' +
            '<p>The editorial team</p>';
          editor.innerHTML = bodyText;
          var hidden = document.getElementById('enr-message');
          if (hidden) hidden.value = bodyText;
        }
      });
    });

    // Filter templates by name
    var search = document.getElementById('enr-template-search');
    var list = document.getElementById('enr-template-list');
    if (search && list) {
      search.addEventListener('input', function () {
        var q = search.value.trim().toLowerCase();
        var items = list.querySelectorAll('.enr-template-item');
        Array.prototype.forEach.call(items, function (item) {
          var name = (item.getAttribute('data-search') || '').toLowerCase();
          item.style.display = (!q || name.indexOf(q) !== -1) ? '' : 'none';
        });
      });
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    initEmailNotification();
  });
})();

// ==========================================
// Upload Review File modal (workflow_3_1)
// ==========================================
var urfFile = null;
var urfStep = 1;
var urfAddedFiles = [];

function urfStoreCurrentFile() {
  if (!urfFile) return;
  var componentSel = document.getElementById('urf-article-component');
  var component = componentSel && componentSel.selectedIndex >= 0
    ? componentSel.options[componentSel.selectedIndex].textContent
    : '';
  urfAddedFiles.push({ name: urfFile.name, size: urfFile.size, component: component });
  renderUrfAddedFiles();
}

function renderUrfAddedFiles() {
  var el = document.getElementById('urf-added-files');
  if (!el) return;
  if (urfAddedFiles.length === 0) {
    el.innerHTML = '';
    return;
  }
  var heading = document.createElement('div');
  heading.className = 'urf-added-files-title';
  heading.textContent = 'Added files (' + urfAddedFiles.length + ')';
  el.appendChild(heading);
  urfAddedFiles.forEach(function(f) {
    var chip = document.createElement('span');
    chip.className = 'urf-added-file-chip';
    chip.textContent = f.component + ' — ' + f.name;
    el.appendChild(chip);
  });
}

window.openUploadRevisionModal = function() {
  var overlay = document.getElementById('upload-revision-overlay');
  if (overlay) overlay.classList.add('urf-open');
  resetUploadRevision();
};

window.closeUploadRevisionModal = function() {
  var overlay = document.getElementById('upload-revision-overlay');
  if (overlay) overlay.classList.remove('urf-open');
  setTimeout(resetUploadRevision, 320);
};

function resetUploadRevision() {
  urfFile = null;
  urfStep = 1;
  urfAddedFiles = [];
  var overlay = document.getElementById('upload-revision-overlay');
  if (!overlay) return;
  var select = document.getElementById('urf-article-component');
  if (select) select.value = '';
  var fileInput = document.getElementById('urf-file-input');
  if (fileInput) fileInput.value = '';
  var nameEl = document.getElementById('urf-file-name');
  if (nameEl) nameEl.textContent = '';
  document.getElementById('urf-btn-upload-file').style.display = 'none';
  document.getElementById('urf-btn-change-file').style.display = 'none';
  showUrfStep(1);
  var cont = document.getElementById('urf-btn-continue');
  if (cont) cont.disabled = true;
  var contLabel = document.getElementById('urf-btn-continue');
  if (contLabel) contLabel.textContent = 'Continue';
  renderUrfAddedFiles();
}

window.onArticleComponentChange = function() {
  var val = document.getElementById('urf-article-component').value;
  var btn = document.getElementById('urf-btn-upload-file');
  if (btn) btn.style.display = val ? 'inline-flex' : 'none';
  if (btn) btn.__component = val;
  updateUrfContinue();
};

window.onFileSelected = function(input) {
  var file = input.files && input.files[0];
  urfFile = file || null;
  if (file) {
    document.getElementById('urf-btn-upload-file').style.display = 'none';
    document.getElementById('urf-btn-change-file').style.display = 'inline-flex';
    var nameEl = document.getElementById('urf-file-name');
    if (nameEl) nameEl.textContent = file.name + ' (' + formatUrfBytes(file.size) + ')';
  } else {
    document.getElementById('urf-btn-change-file').style.display = 'none';
    document.getElementById('urf-btn-upload-file').style.display = 'inline-flex';
    var nameEl2 = document.getElementById('urf-file-name');
    if (nameEl2) nameEl2.textContent = '';
  }
  updateUrfContinue();
};

function formatUrfBytes(bytes) {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function updateUrfContinue() {
  var component = document.getElementById('urf-article-component').value;
  var cont = document.getElementById('urf-btn-continue');
  if (cont) cont.disabled = urfStep === 1 && (!component || !urfFile);
}

function showUrfStep(step) {
  urfStep = step;
  for (var i = 1; i <= 3; i++) {
    var content = document.getElementById('urf-step-' + i);
    if (content) content.classList.toggle('urf-step-hidden', i !== step);
    var indicator = document.getElementById('urf-step-' + i + '-indicator');
    if (indicator) {
      indicator.classList.toggle('urf-step-active', i === step);
      indicator.classList.toggle('urf-step-done', i < step);
      indicator.classList.toggle('urf-step-clickable', i <= step);
    }
  }
  var cont = document.getElementById('urf-btn-continue');
  if (cont) {
    if (step === 1) {
      cont.textContent = 'Continue';
      updateUrfContinue();
    } else if (step === 2) {
      cont.textContent = 'Continue';
      cont.disabled = false;
    } else if (step === 3) {
      cont.textContent = 'Confirm Upload';
      cont.disabled = false;
    }
  }
}

window.urfGoToStep = function(step) {
  if (step > urfStep) return;
  if (step >= 3 && urfStep < 3) return;
  showUrfStep(step);
};

window.urfNextStep = function() {
  if (urfStep === 1) {
    document.getElementById('urf-detail-component').textContent =
      document.querySelector('#urf-article-component option:checked').textContent;
    document.getElementById('urf-detail-filename').textContent =
      urfFile ? urfFile.name : '—';
    document.getElementById('urf-detail-filesize').textContent =
      urfFile ? formatUrfBytes(urfFile.size) : '—';
    showUrfStep(2);
  } else if (urfStep === 2) {
    showUrfStep(3);
  } else if (urfStep === 3) {
    urfStoreCurrentFile();
    closeUploadRevisionModal();
  }
};

window.urfAddAnotherFile = function() {
  urfStoreCurrentFile();
  var select = document.getElementById('urf-article-component');
  if (select) select.value = '';
  var fileInput = document.getElementById('urf-file-input');
  if (fileInput) fileInput.value = '';
  var nameEl = document.getElementById('urf-file-name');
  if (nameEl) nameEl.textContent = '';
  document.getElementById('urf-btn-upload-file').style.display = 'none';
  document.getElementById('urf-btn-change-file').style.display = 'none';
  showUrfStep(1);
};

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('upload-revision-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('urf-open')) {
    overlay.classList.remove('urf-open');
    setTimeout(resetUploadRevision, 320);
  }
});

// ==========================================
// Review File Selection Dialog (workflow_3_1)
// ==========================================

window.openReviewFileSelection = function() {
  var overlay = document.getElementById('review-file-selection-overlay');
  if (overlay) overlay.classList.add('rfs-open');
};

window.closeReviewFileSelection = function() {
  var overlay = document.getElementById('review-file-selection-overlay');
  if (overlay) overlay.classList.remove('rfs-open');
};

window.toggleRfsStages = function() {
  var checked = document.getElementById('rfs-filter-stage');
  var single = document.getElementById('rfs-single-stages');
  var all = document.getElementById('rfs-all-stages');
  var showAll = checked && checked.checked;
  if (single) single.classList.toggle('rfs-stages-hidden', showAll);
  if (all) all.classList.toggle('rfs-stages-hidden', !showAll);
};

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('review-file-selection-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('rfs-open')) {
    overlay.classList.remove('rfs-open');
  }
});

window.arOpenAddReviewerModal = function() {
  var overlay = document.getElementById('add-reviewer-overlay');
  if (overlay) overlay.classList.add('ar-open');
};

window.arToggleFilters = function() {
  var sidebar = document.getElementById('ar-filters-sidebar');
  var btn = document.getElementById('ar-btn-filters');
  if (sidebar) sidebar.classList.toggle('ar-filters-open');
  if (btn) btn.classList.toggle('is-open');
};

window.arAddFilter = function(type) {
  var labels = {
    rated: 'Rated at least',
    completed: 'Reviews completed',
    days: 'Days since last review assigned',
    active: 'Active reviews currently assigned',
    avg: 'Average days to complete review'
  };
  addArActiveFilter(type, labels[type] || type);
};

function addArActiveFilter(key, label) {
  var panel = document.getElementById('ar-filters-sidebar');
  var list = document.getElementById('ar-active-filters');
  var count = document.getElementById('ar-filters-count');
  var keyBtns = {
    rated: 'ar-add-rated',
    completed: 'ar-add-completed',
    days: 'ar-add-days',
    active: 'ar-add-active',
    avg: 'ar-add-avg'
  };
  var addBtn = document.getElementById(keyBtns[key]);
  if (addBtn) addBtn.style.display = 'none';

  var row = document.createElement('div');
  row.className = 'ar-active-filter';
  row.id = 'ar-active-' + key;
  row.setAttribute('data-key', key);
  row.innerHTML =
    '<span class="ar-active-label">' + label + '</span>' +
    '<span class="ar-active-value">' + arFilterInputFor(key) + '</span>' +
    '<button type="button" class="ar-active-remove" onclick="removeArActiveFilter(\'' + key + '\')">&times;</button>';
  list.appendChild(row);

  arUpdateFilterCount();
  arFilterReviewers();
}

function arFilterInputFor(key) {
  var opts = {
    rated: '<input type="number" min="1" max="5" class="ar-mini-input" placeholder="1-5" onchange="arFilterReviewers()" />',
    completed: '<input type="number" min="0" class="ar-mini-input" placeholder="0" onchange="arFilterReviewers()" />',
    days: '<input type="number" min="0" class="ar-mini-input" placeholder="0" onchange="arFilterReviewers()" />',
    active: '<input type="number" min="0" class="ar-mini-input" placeholder="0" onchange="arFilterReviewers()" />',
    avg: '<input type="number" min="0" class="ar-mini-input" placeholder="0" onchange="arFilterReviewers()" />'
  };
  return opts[key] || '';
}

window.removeArActiveFilter = function(key) {
  var row = document.getElementById('ar-active-' + key);
  if (row) row.remove();
  var keyBtns = {
    rated: 'ar-add-rated',
    completed: 'ar-add-completed',
    days: 'ar-add-days',
    active: 'ar-add-active',
    avg: 'ar-add-avg'
  };
  var addBtn = document.getElementById(keyBtns[key]);
  if (addBtn) addBtn.style.display = '';
  arUpdateFilterCount();
  arFilterReviewers();
};

window.arResetFilters = function() {
  var rows = document.querySelectorAll('#ar-active-filters .ar-active-filter');
  rows.forEach(function(r) { r.remove(); });
  ['rated', 'completed', 'days', 'active', 'avg'].forEach(function(key) {
    var addBtn = document.getElementById('ar-add-' + key);
    if (addBtn) addBtn.style.display = '';
  });
  arUpdateFilterCount();
  arFilterReviewers();
};

function arUpdateFilterCount() {
  var count = document.getElementById('ar-filters-count');
  var n = document.querySelectorAll('#ar-active-filters .ar-active-filter').length;
  if (count) count.textContent = n ? n + ' filter' + (n > 1 ? 's' : '') : '';
}

window.closeAddReviewerModal = function() {
  var overlay = document.getElementById('add-reviewer-overlay');
  if (overlay) overlay.classList.remove('ar-open');
  arCloseAllDropdowns();
};

window.arFilterReviewers = function() {
  var input = document.getElementById('ar-search-input');
  var query = (input && input.value || '').toLowerCase().trim();
  var cards = document.querySelectorAll('#ar-reviewer-list .ar-reviewer-card');
  var visible = 0;
  cards.forEach(function(card) {
    var name = card.getAttribute('data-name') || '';
    var match = name.indexOf(query) !== -1;
    card.style.display = match ? '' : 'none';
    if (match) visible++;
  });
  var noResults = document.getElementById('ar-no-results');
  if (noResults) noResults.style.display = visible === 0 ? '' : 'none';
};

window.arToggleDropdown = function(btn) {
  arCloseAllDropdowns();
  var wrap = btn.closest('.ar-reviewer-select-wrap');
  var dropdown = wrap && wrap.querySelector('.ar-select-dropdown');
  if (dropdown) dropdown.classList.add('ar-open');
  window.__activeArBtn = btn;
};

window.arSelectReviewer = function(formId) {
  var form = document.getElementById(formId);
  if (form) form.submit();
};

window.arCloseAllDropdowns = function() {
  var open = document.querySelectorAll('.ar-select-dropdown.ar-open');
  open.forEach(function(d) { d.classList.remove('ar-open'); });
};

window.arOpenCreateReviewer = function() {
  alert('Create New Reviewer coming soon.');
};

window.arOpenEnrollUser = function() {
  alert('Enroll Existing User coming soon.');
};

document.addEventListener('click', function(e) {
  if (e.target.closest('.ar-select-reviewer-btn')) return;
  arCloseAllDropdowns();
});

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('add-reviewer-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('ar-open')) {
    overlay.classList.remove('ar-open');
    arCloseAllDropdowns();
  }
});

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    var overlay = document.getElementById('add-reviewer-overlay');
    if (overlay && overlay.classList.contains('ar-open')) {
      overlay.classList.remove('ar-open');
      arCloseAllDropdowns();
    }
  }
});

// ==========================================
// Assign Participant drawer (workflow_1)
// ==========================================
window.openAssignParticipantDrawer = function() {
  var overlay = document.getElementById('assign-participant-drawer');
  if (overlay) {
    overlay.classList.add('apd-open');
    apdReset();
  }
};

window.closeAssignParticipantDrawer = function() {
  var overlay = document.getElementById('assign-participant-drawer');
  if (overlay) overlay.classList.remove('apd-open');
};

function apdReset() {
  var role = document.getElementById('apd-role-filter');
  var search = document.getElementById('apd-search-name');
  var msg = document.getElementById('apd-predefined-message');
  var editor = document.getElementById('apd-message-editor');
  if (role) role.value = 'editor';
  if (search) search.value = '';
  if (msg) msg.value = '';
  if (editor) editor.innerHTML = '';
  document.getElementById('apd-form-user-id').value = '';
  document.getElementById('apd-form-username').value = '';
  document.getElementById('apd-form-role').value = '';
  document.getElementById('apd-form-message').value = '';
  apdFilterUsers();
}

window.apdFilterUsers = function() {
  var roleSel = document.getElementById('apd-role-filter');
  var input = document.getElementById('apd-search-name');
  var roleValue = roleSel ? roleSel.value : '';
  var query = (input && input.value || '').toLowerCase().trim();
  var users = window.__apUsers || [];
  var tbody = document.getElementById('apd-users-tbody');
  var noResults = document.getElementById('apd-no-results');

  var filtered = users.filter(function(u) {
    var matchRole = (roleValue === '') || (u.role === roleValue);
    var name = ((u.given_name || '') + ' ' + (u.family_name || '')).toLowerCase();
    var matchQuery = !query || name.indexOf(query) !== -1 || (u.email || '').toLowerCase().indexOf(query) !== -1;
    return matchRole && matchQuery;
  });

  tbody.innerHTML = '';
  if (filtered.length === 0) {
    if (noResults) noResults.style.display = 'block';
  } else {
    if (noResults) noResults.style.display = 'none';
    filtered.forEach(function(u) {
      var name = ((u.given_name || '') + ' ' + (u.family_name || '')).trim() || u.username;
      var tr = document.createElement('tr');
      tr.className = 'apd-user-row';
      tr.setAttribute('data-user-id', u.id);
      tr.setAttribute('data-username', u.username);
      tr.onclick = function() { apdSelectUser(u.id, u.username, name, tr); };
      tr.innerHTML =
        '<td><div class="apd-row-name">' + apdEscapeHtml(name) + '</div><div class="apd-row-email">' + apdEscapeHtml(u.email || '') + '</div></td>' +
        '<td>' + (u.reviews_completed || 0) + '</td>' +
        '<td>' + apdEscapeHtml(u.affiliation || '\u2014') + '</td>' +
        '<td>' + apdEscapeHtml(u.reviewing_interests || '\u2014') + '</td>';
      tbody.appendChild(tr);
    });
  }
}

function apdSelectUser(userId, username, name, row) {
  document.querySelectorAll('.apd-user-row').forEach(function(r) { r.classList.remove('apd-user-selected'); });
  row.classList.add('apd-user-selected');
  document.getElementById('apd-form-user-id').value = userId;
  document.getElementById('apd-form-username').value = username;
  var roleSel = document.getElementById('apd-role-filter');
  document.getElementById('apd-form-role').value = roleSel ? roleSel.value : '';
}

window.apdApplyPredefinedMessage = function(value) {
  var editor = document.getElementById('apd-message-editor');
  if (!value || !editor) return;
  if (value === 'discussion') {
    editor.innerHTML = '<p>Dear Editor,</p><p>I have submitted my manuscript for consideration. Please let me know if there is anything else you need.</p>';
  } else if (value === 'assign_editor') {
    editor.innerHTML = '<p>You have been assigned as the editor of record for this submission. Please proceed with the editorial workflow.</p>';
  }
};

window.apdSubmit = function() {
  var userId = document.getElementById('apd-form-user-id').value;
  if (!userId) {
    alert('Please select a user first.');
    return;
  }
  var editor = document.getElementById('apd-message-editor');
  document.getElementById('apd-form-message').value = editor ? editor.innerHTML : '';
  document.getElementById('assign-participant-form').submit();
};

function apdEscapeHtml(str) {
  var div = document.createElement('div');
  div.appendChild(document.createTextNode(str));
  return div.innerHTML;
}

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('assign-participant-drawer');
  if (overlay && e.target === overlay && overlay.classList.contains('apd-open')) {
    overlay.classList.remove('apd-open');
  }
});

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    var overlay = document.getElementById('assign-participant-drawer');
    if (overlay && overlay.classList.contains('apd-open')) {
      overlay.classList.remove('apd-open');
    }
  }
});

// Init richtext toolbar for assign participant drawer
document.querySelectorAll('.apd-richtext-toolbar .apd-richtext-btn').forEach(function(btn) {
  btn.addEventListener('mousedown', function(e) { e.preventDefault(); });
  btn.addEventListener('click', function() {
    var cmd = btn.getAttribute('data-cmd');
    document.getElementById('apd-message-editor').focus();
    document.execCommand(cmd, false, null);
  });
});

// ==========================================
// Pre-Review Discussion modal (workflow_1)
// ==========================================
window.openPreDiscussionModal = function() {
  var overlay = document.getElementById('pre-discussion-overlay');
  if (overlay) overlay.classList.add('prd-open');
};

window.closePreDiscussionModal = function() {
  var overlay = document.getElementById('pre-discussion-overlay');
  if (overlay) overlay.classList.remove('prd-open');
};

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('pre-discussion-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('prd-open')) {
    overlay.classList.remove('prd-open');
  }
});

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    var overlay = document.getElementById('pre-discussion-overlay');
    if (overlay && overlay.classList.contains('prd-open')) {
      overlay.classList.remove('prd-open');
    }
  }
});

window.addEventListener('DOMContentLoaded', function() {
  var form = document.getElementById('pre-discussion-form');
  if (!form) return;

  var selfOnly = form.getAttribute('data-self-only') === 'true';

  form.addEventListener('submit', function(e) {
    if (!selfOnly) return;
    e.preventDefault();
    var errorBox = document.getElementById('prd-self-only-error');
    if (errorBox) errorBox.style.display = 'block';
  });

  form.addEventListener('input', function() {
    var errorBox = document.getElementById('prd-self-only-error');
    if (errorBox && errorBox.style.display !== 'none') {
      errorBox.style.display = 'none';
    }
  });
});

// ==========================================
// Comment for the Editor detail panel (workflow_1)
// ==========================================
window.openEditorCommentPanel = function() {
  var overlay = document.getElementById('editor-comment-overlay');
  if (overlay) overlay.classList.add('prd-open');
};

window.closeEditorCommentPanel = function() {
  var overlay = document.getElementById('editor-comment-overlay');
  if (overlay) overlay.classList.remove('prd-open');
};

window.togglePcdReplySection = function(force) {
  var section = document.getElementById('pcd-reply-section');
  if (!section) return;
  section.style.display =
    typeof force === 'boolean' ? (force ? 'block' : 'none') : section.style.display === 'none' ? 'block' : 'none';
  if (section.style.display !== 'none') {
    var editor = document.getElementById('pcd-message-editor');
    if (editor) editor.focus();
  }
};

document.addEventListener('click', function(e) {
  var btn = e.target.closest('.pcd-btn-add-message');
  if (!btn) return;
  window.togglePcdReplySection();
});

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('editor-comment-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('prd-open')) {
    overlay.classList.remove('prd-open');
  }
});

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    var overlay = document.getElementById('editor-comment-overlay');
    if (overlay && overlay.classList.contains('prd-open')) {
      overlay.classList.remove('prd-open');
    }
  }
});

// ==========================================
// Upload Discussion File modal (workflow_1)
// ==========================================
var udfFile = null;
var udfStep = 1;
var udfAttachedFiles = [];

window.openUploadDiscussionFileModal = function() {
  var overlay = document.getElementById('upload-discussion-file-overlay');
  if (overlay) overlay.classList.add('udf-open');
  resetUdf();
};

window.closeUploadDiscussionFileModal = function() {
  var overlay = document.getElementById('upload-discussion-file-overlay');
  if (overlay) overlay.classList.remove('udf-open');
  setTimeout(resetUdf, 320);
};

function resetUdf() {
  udfFile = null;
  udfStep = 1;
  udfAttachedFiles = [];
  var select = document.getElementById('udf-article-component');
  if (select) select.value = '';
  var fileInput = document.getElementById('udf-file-input');
  if (fileInput) fileInput.value = '';
  var nameEl = document.getElementById('udf-file-name');
  if (nameEl) nameEl.textContent = '';
  var nameInput = document.getElementById('udf-file-name-input');
  if (nameInput) nameInput.value = '';
  var uploadBtn = document.getElementById('udf-btn-upload-file');
  if (uploadBtn) uploadBtn.style.display = 'none';
  var changeBtn = document.getElementById('udf-btn-change-file');
  if (changeBtn) changeBtn.style.display = 'none';
  showUdfStep(1);
  var cont = document.getElementById('udf-btn-continue');
  if (cont) cont.disabled = true;
}

window.onUdfArticleComponentChange = function() {
  var val = document.getElementById('udf-article-component').value;
  var btn = document.getElementById('udf-btn-upload-file');
  if (btn) btn.style.display = val ? 'inline-flex' : 'none';
  updateUdfContinue();
};

window.onUdfFileSelected = function(input) {
  var file = input.files && input.files[0];
  udfFile = file || null;
  if (file) {
    var uploadBtn = document.getElementById('udf-btn-upload-file');
    if (uploadBtn) uploadBtn.style.display = 'none';
    var changeBtn = document.getElementById('udf-btn-change-file');
    if (changeBtn) changeBtn.style.display = 'inline-flex';
    var nameEl = document.getElementById('udf-file-name');
    if (nameEl) nameEl.textContent = file.name + ' (' + formatUdfBytes(file.size) + ')';
  } else {
    var changeBtn2 = document.getElementById('udf-btn-change-file');
    if (changeBtn2) changeBtn2.style.display = 'none';
    var uploadBtn2 = document.getElementById('udf-btn-upload-file');
    if (uploadBtn2) uploadBtn2.style.display = 'inline-flex';
    var nameEl2 = document.getElementById('udf-file-name');
    if (nameEl2) nameEl2.textContent = '';
  }
  updateUdfContinue();
};

function formatUdfBytes(bytes) {
  if (!bytes && bytes !== 0) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function updateUdfContinue() {
  var component = document.getElementById('udf-article-component').value;
  var cont = document.getElementById('udf-btn-continue');
  if (cont) cont.disabled = udfStep === 1 && (!component || !udfFile);
}

function showUdfStep(step) {
  udfStep = step;
  for (var i = 1; i <= 3; i++) {
    var content = document.getElementById('udf-step-' + i);
    if (content) content.classList.toggle('udf-step-hidden', i !== step);
    var indicator = document.getElementById('udf-step-' + i + '-indicator');
    if (indicator) {
      indicator.classList.toggle('udf-step-active', i === step);
      indicator.classList.toggle('udf-step-done', i < step);
      indicator.classList.toggle('udf-step-clickable', i <= step);
    }
  }
  var cont = document.getElementById('udf-btn-continue');
  if (cont) {
    if (step === 1) {
      cont.textContent = 'Continue';
      updateUdfContinue();
    } else if (step === 2) {
      cont.textContent = 'Continue';
      cont.disabled = !getUdfFileName();
    } else if (step === 3) {
      cont.textContent = 'Attach to Discussion';
      cont.disabled = false;
    }
  }
}

window.udfGoToStep = function(step) {
  if (step > udfStep) return;
  if (step >= 3 && udfStep < 3) return;
  showUdfStep(step);
};

function getUdfFileName() {
  var input = document.getElementById('udf-file-name-input');
  return input ? (input.value || '').trim() : '';
}

window.updateUdfNameDetail = function() {
  var cont = document.getElementById('udf-btn-continue');
  if (cont) cont.disabled = !getUdfFileName();
};

window.udfNextStep = function() {
  if (udfStep === 1) {
    var nameInput = document.getElementById('udf-file-name-input');
    if (nameInput && udfFile) {
      nameInput.value = udfFile.name;
      nameInput.value = nameInput.value.replace(/\.[^/.]+$/, '');
    }
    updateUdfNameDetail();
    showUdfStep(2);
  } else if (udfStep === 2) {
    showUdfStep(3);
  } else if (udfStep === 3) {
    udfAttachFile();
  }
};

window.udfAttachFile = function() {
  var component = document.querySelector('#udf-article-component option:checked').textContent;
  var name = getUdfFileName();
  if (udfFile && component && name) {
    udfAttachedFiles.push({
      component: component,
      name: name,
      size: udfFile.size
    });
    udfRenderAttached();
    var attachBox = document.querySelector('.prd-attach-box .prd-attach-body');
    if (attachBox) {
      attachBox.innerHTML = '';
      udfAttachedFiles.forEach(function(f) {
        var row = document.createElement('div');
        row.className = 'prd-attach-file-row';
        row.innerHTML = '<span class="prd-attach-file-chip">' +
          f.component + ' — ' + f.name + '</span>';
        attachBox.appendChild(row);
      });
      var hidden = document.getElementById('prd-attached-files');
      if (hidden) hidden.value = JSON.stringify(udfAttachedFiles);
    }
  }
  closeUploadDiscussionFileModal();
};

function udfRenderAttached() {
  var el = document.getElementById('udf-added-files');
  if (!el) return;
  el.innerHTML = '';
  if (udfAttachedFiles.length === 0) return;
  var heading = document.createElement('div');
  heading.className = 'udf-added-files-title';
  heading.textContent = 'Attached files (' + udfAttachedFiles.length + ')';
  el.appendChild(heading);
  udfAttachedFiles.forEach(function(f) {
    var chip = document.createElement('span');
    chip.className = 'udf-added-file-chip';
    chip.textContent = f.component + ' — ' + f.name;
    el.appendChild(chip);
  });
}

document.addEventListener('click', function(e) {
  var overlay = document.getElementById('upload-discussion-file-overlay');
  if (overlay && e.target === overlay && overlay.classList.contains('udf-open')) {
    overlay.classList.remove('udf-open');
    setTimeout(resetUdf, 320);
  }
});

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    var overlay = document.getElementById('upload-discussion-file-overlay');
    if (overlay && overlay.classList.contains('udf-open')) {
      overlay.classList.remove('udf-open');
      setTimeout(resetUdf, 320);
    }
  }
});

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