App.Controllers.Products = Backbone.Controller.extend

  initialize: ->
    # 列表页面的查询条件：类型、厂商
    $('#vendor-filter-link').click ->
      $('#type-status-select > .dropdown').hide()
      $('#vendor-status-select > .dropdown').toggle()
      false

    $('#type-filter-link').click ->
      $('#vendor-status-select > .dropdown').hide()
      $('#type-status-select > .dropdown').toggle()
      false

    $(document).click ->
      $('#vendor-status-select > .dropdown').hide()
      $('#type-status-select > .dropdown').hide()

    ###### 新增及查看页面 #####
    # 是否要求收货地址
    $('body').delegate "input.requires_shipping", 'change', ->
      container = $(this).parent().closest('table').parent().closest('table')
      requires_shipping_relate = $('.requires_shipping_relate', container)
      if $(this).attr('checked') is 'checked'
        requires_shipping_relate.attr('disabled', false)
      else
        requires_shipping_relate.attr('disabled', true).val('0.0')
    $("input.requires_shipping").change()

    # 是否跟踪库存
    $('body').delegate "select.inventory_management", 'change', ->
      container = $(this).parent().parent().parent()
      inventory_management_relate = $('.inventory_management_relate', container)
      if $(this).val() is ''
        $("input[name='product[variants_attributes][][inventory_quantity]']").val('')
        inventory_management_relate.hide()
      else
        quantity = $("input[name='product[variants_attributes][][inventory_quantity]']")
        if !quantity.val()
          quantity.val('1')
        inventory_management_relate.show()
    $("select.inventory_management").change()

    Utils.Tag.init 'product_tags_text' #标签(新增、修改商品时)

    #显示上传图片的form
    $('#upload-label .show-upload-link').click ->
      $(this).hide()
      $("#upload-area").toggle()

    #照片排序
    $("#image_list").sortable handle: '.image-drag', update: (event,ui) ->
      $.post $(this).attr('url'), $(this).sortable('serialize')


  routes:
    "nothing":      "nothing"
