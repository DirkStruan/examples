/* Просто небольшой пример спагетти кода, который я написал */

$(document).ready(function() {
  function handleNavigationSelectChange() {
    $('.wt-navigation-select').on('change', function(e){
      if(this.value != 0){
        window.location = this.value
      }
    })
  }

  function handleAddingNewTimeEntry() {
    $('body').on('click', '.add-new-time-entry-button', function(e){
      var $this = $(this);
      var issueId = this.dataset.issueId;

      var newTableRow = copyAndCleanTableRow($this.parents('tr'), issueId);

      insertRowToParentTable($this, issueId, newTableRow);
      insertRowToPinnedTable($this, issueId, newTableRow.clone());
    });
  }

  function copyAndCleanTableRow(row, issueId) {
    var newRow = row.clone();
    $(newRow).find('input[type=checkbox]').prop('checked', false);
    $(newRow).find('input[type=text]').val('');
    $(newRow).find('input[type=number]').val('');
    $(newRow).find('input[type=hidden][name$="[id]"]').val('');

    var newEntryId = (new Date()).getTime();
    changeIdsAndNames($(newRow).find('input'), issueId, newEntryId);
    changeIdsAndNames($(newRow).find('select'), issueId, newEntryId);

    return newRow;
  }

  function insertRowToParentTable(context, issueId, newTableRow) {
    context.closest('table').find('tr[data-issue-id=' + issueId + ']').last().after(newTableRow);
  }

  function insertRowToPinnedTable(context, issueId, newTableRow) {
    var responsiveTableWrapper = context.parents('.table-wrapper');
    if(responsiveTableWrapper.length){
      responsiveTableWrapper.find('.pinned tr[data-issue-id=' + issueId + ']').last().after(newTableRow);
    }
  }

  function changeIdsAndNames(collection, issueId, newEntryId) {
    collection.each(function(i, element){
      element.id = element.id.replace(/^time_entries_time_entry_\d+/, 'time_entries_time_entry_' + newEntryId)
      element.name = element.name.replace(/^time_entries\[time_entry\]\[\d+/, 'time_entries[time_entry][' + newEntryId)
    });
  }

  function restrictCharacters(event, charactersRegexp) {
    var key = String.fromCharCode(!event.charCode ? event.which : event.charCode);
    if (isNotSpecialKey(event.keyCode) && !key.match(charactersRegexp)) {
      event.preventDefault();
      return false;
    }
  };

  function isNotSpecialKey(keyCode) {
    var specialKeyCodes = [8, 13, 37, 39, 26];
    !specialKeyCodes.some(function(number){
      return (number == keyCode)
    })
  }

  function synchronizeIssueStatusSelects() {
    $(document).on('input', 'body [data-role="select-status"]', function(e) {
      var $firstChangesSelect = $(this);
      $('[data-role="select-status"][data-issue-id="' + $firstChangesSelect.data('issue-id') + '"]').each(function(){
        if($(this) != $firstChangesSelect){
          var select = $(this).val($firstChangesSelect.val());
          select.find('options').each(function() {
            if(this.value != $firstChangesSelect.val()){
              this.selected = null;
            } else {
              this.selected = 'selected';
            }
          })
        }
      });
    })
  }

  function navigateToDate(date) {
    var currentLocation = window.location.href

    if (currentLocation.match(/date=/)){
      var destinationLocation = currentLocation.replace(/date=\d{2,4}[.-]\d{2}[.-]\d{2,4}/, 'date=' + date);
    } else {
      var specialCharacter = currentLocation.match(/\?/) ? '&' : '?'
      var destinationLocation = currentLocation + specialCharacter + 'date=' + date;
    }

    window.location.href = destinationLocation;
  }

  function autoScrollFocusedCommentInput() {
    $(document).on('focus', 'body .wt-day-table .scrollable td.wt-comment input', function() {
      var scrollSize = $("td.wt-summary-time")[0].offsetWidth
      $(this).closest('.scrollable').animate({ scrollLeft: scrollSize }, { duration: 'fast' });
    })
  }

  $(document).on('click', '.wt-switch-closed > div', function() {

    $('.wt-show-closed, .wt-hide-closed, tr.wt-issue-closed').toggle();

  });

  $(document).on('click', 'body .wt-primary-action input[type=submit]', function(e) {
    $(this).addClass('disabled');
  });

  $(document).on('keypress', 'body .wt-time-input', function(e) {
    restrictCharacters(e, new RegExp("^[0-9.,]$"))
  });

  $(document).on('keypress', 'body .wt-secondary-action input[name="new_issue_id"]', function(e) {
    restrictCharacters(e, new RegExp("^[0-9]$"));
  });

  $(document).on('change', 'body #wt-choose-date-calendar', function(e) {
    var date = $(this).val();

    navigateToDate(date);
  })

  $(document).on('click', 'body .wt-rep-date:not(.wt-rep-date-future)', function(e) {
    navigateToDate($(this).attr('data-date'));
  })

  $('.wt-add-issue, .wt-add-issue-cancel').click(function() {
    $('.wt-primary-action, .wt-secondary-action').toggle();
  });

  $('.wt-add-issue').click(function() {
    $('.wt-secondary-action input').focus();
  });

  $('.wt-add-issue').click(function(){
    $('#wt-add-issue-form-container').removeClass('hidden');
  });

  $('.wt-add-issue-cancel').click(function(){
    var $addIssueFormContainer = $('#wt-add-issue-form-container');
    $addIssueFormContainer.addClass('hidden');
    $addIssueFormContainer.find('input[type=number]').val('');
    $addIssueFormContainer.find('button.btn-primary').attr('disabled', 'disabled');
  });

  handleNavigationSelectChange();
  handleAddingNewTimeEntry();
  synchronizeIssueStatusSelects();
  autoScrollFocusedCommentInput();
});
