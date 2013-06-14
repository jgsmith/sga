# # Components

SGAReader.namespace "Component", (Component) ->

  #
  # ## Component.ProgressBar
  #
  Component.namespace "ProgressBar", (ProgressBar) ->
    ProgressBar.initInstance = (args...) ->
      MITHGrid.initInstance "SGA.Reader.Component.ProgressBar", args..., (that, container) ->
        that.events.onNumeratorChange.addListener (n) ->
          percent = parseInt(100 * n / that.getDenominator(), 10)
          percent = 100 if percent > 100
          $(container).find(".bar").css("width", percent + "%")
        that.events.onDenominatorChange.addListener (d) ->
          percent = parseInt(100 * that.getNumerator() / d, 10)
          percent = 100 if percent > 100
          $(container).find(".bar").css("width", percent + "%")

        that.show = -> 
          $(container).show()
        that.hide = -> 
          $(container).hide()

  #
  # ## Component.SequenceSelector
  #
  Component.namespace "SequenceSelector", (SequenceSelector) ->
    SequenceSelector.initInstance = (args...) ->
      MITHGrid.Presentation.initInstance "SGA.Reader.Component.SequenceSelector", args..., (that, container) ->
        options = that.options
        # container should be a <select/> element
        that.addLens 'Sequence', (container, view, model, id) ->
          rendering = {}
          item = model.getItem id
          el = $("<option></option>")
          el.attr
            value: id
          el.text item.label?[0]
          $(container).append(el)

        $(container).change ->
          that.setSequence $(container).val()

        that.finishDisplayUpdate = ->
          that.setSequence $(container).val()

  #
  # ## Component.Slider
  #
  Component.namespace "Slider", (Slider) ->
    Slider.initInstance = (args...) ->
      MITHGrid.initInstance "SGA.Reader.Component.Slider", args..., (that, container) ->
        that.events.onMinChange.addListener (n) ->
          $(container).attr
            min: n
        that.events.onMaxChange.addListener (n) ->
          $(container).attr
            max: n
        that.events.onValueChange.addListener (n) -> $(container).val(n)
        $(container).change (e) -> that.setValue $(container).val()

  #
  # ## Component.PagerControls
  #
  Component.namespace "PagerControls", (PagerControls) ->
    PagerControls.initInstance = (args...) ->
      MITHGrid.initInstance "SGA.Reader.Component.PagerControls", args..., (that, container) ->
        firstEl = $(container).find(".icon-fast-backward").parent()
        prevEl = $(container).find(".icon-step-backward").parent()
        nextEl = $(container).find(".icon-step-forward").parent()
        lastEl = $(container).find(".icon-fast-forward").parent()

        that.events.onMinChange.addListener (n) ->
          if n < that.getValue()
            firstEl.removeClass "disabled"
            prevEl.removeClass "disabled"
          else
            firstEl.addClass "disabled"
            prevEl.addClass "disabled"

        that.events.onMaxChange.addListener (n) ->
          if n > that.getValue()
            nextEl.removeClass "disabled"
            lastEl.removeClass "disbaled"
          else
            nextEl.addClass "disabled"
            lastEl.addClass "disabled"

        that.events.onValueChange.addListener (n) ->
          if n > that.getMin()
            firstEl.removeClass "disabled"
            prevEl.removeClass "disabled"
          else
            firstEl.addClass "disabled"
            prevEl.addClass "disabled"

          if n < that.getMax()
            nextEl.removeClass "disabled"
            lastEl.removeClass "disabled"
          else
            nextEl.addClass "disabled"
            lastEl.addClass "disabled"

        $(prevEl).click (e) ->
          e.preventDefault()
          that.addValue -1
        $(nextEl).click (e) ->
          e.preventDefault()
          that.addValue 1
        $(firstEl).click (e) ->
          e.preventDefault()
          that.setValue that.getMin()
        $(lastEl).click (e) ->
          e.preventDefault()
          that.setValue that.getMax()

#
  # ## Component.PagerControls
  #
  Component.namespace "ImageControls", (ImageControls) ->
    ImageControls.initInstance = (args...) ->
      MITHGrid.initInstance "SGA.Reader.Component.ImageControls", args..., (that, container) ->        
        resetEl = $(container).find(".icon-picture").parent()
        inEl = $(container).find(".icon-zoom-in").parent()
        outEl = $(container).find(".icon-zoom-out").parent()
        marqueeEl = $(container).find(".icon-eye-open").parent()

        $(resetEl).click (e) ->
          e.preventDefault()
          that.setZoom that.getMinZoom()
          that.setImgPosition 
            topLeft:
              x: 0,
              y: 0,
            bottomRight:
              x: 0,
              y: 0

        $(inEl).click (e) ->
          e.preventDefault()
          zoom = that.getZoom()
          if Math.floor zoom+1 <= that.getMaxZoom()
            that.setZoom Math.floor zoom+1

        $(outEl).click (e) ->
          e.preventDefault()
          zoom = that.getZoom()
          minZoom = that.getMinZoom()
          if Math.floor zoom-1 > minZoom
            that.setZoom Math.floor zoom-1
          else if Math.floor zoom-1 == Math.floor minZoom
            that.setZoom minZoom

        $(marqueeEl).click (e) ->
          e.preventDefault()
          marquees = $('.marquee')
          marquees.each (i, m) ->
            m = $(m)            
            if m.css("display") != "none"
              m.hide()
            else 
              m.show()