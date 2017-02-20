# Этот класс был создан, чтобы посылать файлы при помощи XHR запроса, при перетаскивании его в некоторую область. 
# Изначально стояла задача узнать почему не работает Drag and Drop для FireFox. 
# Как выяснилось причина состояла в ограничениях FireFox, связанных с безопасностью. 
# Дело в том что мы слушали событие DROP конкретной области, и, если при перетаскивании в e.originalEvent.dataTransfer.files был файл, 
# то мы клали в input[type=file] эти файлы и сабмитили форму. Однако как выяснилось в FireFox из соображений безопасности запрещено 
# устанавливать значение input[type=file]. Следовательно необходимо было найти другой способ отправить данные на сервер.
# Решение: 
# 1. Упаковать данные при помощи класса FormData
# 2. Отправить XHR запрос, установив HTTP заголовок X-CSRF-Token  

class window.FirefoxDragAndDropHandler
  constructor: (resourceFormSelector, options = {})->
    @resourceFormSelector = resourceFormSelector

    @previewIcon = options.previewIcon || (->)
    @attachFilesAsNestedAttributes = options.attachFilesAsNestedAttributes || (->)
    @fileFieldName = options.fileFieldName || (->)
    @subscribe()

  subscribe: ->
    if navigator.userAgent.toLowerCase().indexOf('firefox') > -1
      if $('body').hasClass('new') or $('body').hasClass('create')
        @attachFileToNewResource()
      else
        @attachFileToExistingResource()

  attachFileToNewResource: ->
    sendXHRRequest = @sendXHRRequest
    attachedFilesBatches = []
    newInputIndex = parseInt($("input[name$='][invoice][]']:last").attr('name').match(/\d+/)[0]) + 1
    previewIcon = @previewIcon
    attachFilesAsNestedAttributes = @attachFilesAsNestedAttributes

    $('body')
      .on 'drop', @resourceFormSelector, (e)->
        inputIndex = if attachedFilesBatches.length
          attachedFilesBatches[attachedFilesBatches.length-1][0] + 1
        else
          newInputIndex
        attachFilesAsNestedAttributes(e.originalEvent.dataTransfer.files, inputIndex)
        attachedFilesBatches.push([inputIndex, e.originalEvent.dataTransfer.files])
      .on 'submit', '#editor_form', (e)->
        e.preventDefault()
        e.stopPropagation()
        formData = new FormData(@)
        for attachedFileBatch in attachedFilesBatches
          for file in attachedFileBatch[1]
            formData.append("pd_request[invoices_attributes][#{newInputIndex++}][invoice]", file)

        sendXHRRequest($(@).attr('action'), formData, false)

      .on 'click', '.delete-icon', ->
        deleteIndex = attachedFilesBatches.map((e) -> e[0]).indexOf($(@).data('index'))
        attachedFilesBatches.splice(deleteIndex, 1)

  attachFileToExistingResource: ->
    resourceFormSelector = @resourceFormSelector
    fileFieldName = @fileFieldName
    sendXHRRequest = @sendXHRRequest
    $('body').on 'drop', resourceFormSelector, (e)->
      formData = new FormData()
      for file in e.originalEvent.dataTransfer.files
        formData.append(fileFieldName, file)

      sendXHRRequest($(resourceFormSelector).attr('action') + '.js', formData, true)

  sendXHRRequest: (url, formData, async)->
    $.ajax(
      method: 'POST',
      url: url,
      async: async,
      processData: false,
      contentType: false,
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      data: formData,
      success: (data, textStatus, xhr)->
        unless async
          document.open()
          document.write(data)
          document.close()
          if data.redirectURL
            window.location.href = data.redirectURL
          else
            history.pushState('', '', url)
    )


class window.InvoicesFirefoxDragAndDropHandler extends FirefoxDragAndDropHandler
  attachFileToNewResource: ->
    sendXHRRequest = @sendXHRRequest
    attachmentFile = ''
    previewIcon = @previewIcon

    $('body')
    .on 'drop', @resourceFormSelector, (e)->
      attachmentFile = e.originalEvent.dataTransfer.files[0]
      if attachmentFile
        previewIcon(attachmentFile)
    .on 'submit', '#new_pd_invoice_0', (e)->
      e.preventDefault()

      formData = new FormData(@)
      if attachmentFile
        formData.append("pd_invoice[attachment]", attachmentFile)

      sendXHRRequest($(@).attr('action'), formData, false)

    .on 'click', '[role="cancel-file-attachment"]', (e)->
      e.preventDefault()
      attachmentFile = ''
