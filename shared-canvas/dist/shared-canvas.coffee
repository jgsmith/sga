###
# SGA Shared Canvas v0.132170
#
# **SGA Shared Canvas** is a shared canvas reader written in CoffeeScript.
#
# Date: Wed Jul 10 15:32:59 2013 -0400
#
# (c) Copyright University of Maryland 2012-2013.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###

(($, MITHgrid) ->
  #
  # The application uses the SGA.Reader namespace.
  #
  # N.B.: This may change as we move towards a general component
  # repository for MITHgrid. At that point, we'll refactor out the
  # general purpose components and keep the SGA namespace for code
  # specific to the SGA project.
  #
  MITHgrid.globalNamespace "SGA"
  SGA.namespace "Reader", (SGAReader) ->
    # # Data Managment
    SGAReader.namespace "Data", (Data) ->
    
      #
      # ## Data.StyleStore
      #
    
      Data.namespace "StyleStore", (StyleStore) ->
        StyleStore.initInstance = (args...) ->
          MITHgrid.initInstance args..., (that) ->
            options = that.options
    
            docs = { }
            regex = new RegExp("(?:\\.(\\S+)\\s*\\{\\s*([^}]*)\\s*\\})", "mg")
    
            #
            # Associates the CSS content with the given id.
            #
            that.addStyles = (id, css) ->
              return if docs[id]?
              docs[id] = { }
              results = regex.exec(css)
              while results?.index?
                docs[id][results[1]] = results[2]
                results = regex.exec(css)
    
            #
            # Returns the CSS style rules for a given class as defined by the
            # CSS content associated with the given id.
            #
            that.getStylesForClass = (id, klass) ->
              if docs[id]?[klass]?
                docs[id][klass]
              else
                ""
    
      #
      # ## Data.TextStore
      #
      Data.namespace "TextStore", (TextStore) ->
        TextStore.initInstance = (args...) ->
          MITHgrid.initInstance args..., (that) ->
            options = that.options
    
            fileContents = { }
            loadingFiles = { }
            pendingFiles = { }
    
            that.addFile = (files) ->
              files = [ files ] unless $.isArray(files)
              for file in files 
                do (file) ->
                  if file? and !fileContents[file]? and !loadingFiles[file]?
                    loadingFiles[file] = [ ]
                    $.ajax
                      url: file
                      type: 'GET'
                      processData: false
                      success: (data) ->
                        c = data.documentElement.textContent
                        fileContents[file] = c
                        f(c) for f in loadingFiles[file]
                        delete loadingFiles[file]
    
            that.withFile = (file, cb) ->
              if fileContents[file]?
                cb(fileContents[file])
              else if loadingFiles[file]?
                loadingFiles[file].push cb
              else
                that.addFile file
                loadingFiles[file].push cb
    
      #
      # ## Data.Manifest
      #
      Data.namespace "Manifest", (Manifest) ->
    
        #
        # We list all of the namespaces that we care about and the prefix
        # we map them to. Some of the namespaces are easy "misspellings"
        # that let us support older namespaces.
        #
        NS =
          "http://dms.stanford.edu/ns/": "sc"
          "http://www.shared-canvas.org/ns/": "sc"
          "http://www.w3.org/2000/01/rdf-schema#": "rdfs"
          "http://www.w3.org/1999/02/22-rdf-syntax-ns#": "rdf"
          "http://www.w3.org/2003/12/exif/ns#": "exif"
          "http://purl.org/dc/elements/1.1/": "dc"
          "http://www.w3.org/ns/openannotation/core/": "oa"
          "http://www.openannotation.org/ns/": "oa"
          "http://www.w3.org/ns/openannotation/extension/": "oax"
          "http://www.openarchives.org/ore/terms/": "ore"
          "http://www.shelleygodwinarchive.org/ns/1#": "sga"
          "http://www.shelleygodwinarchive.org/ns1#": "sga"
          "http://www.w3.org/2011/content#": "cnt"
          "http://purl.org/dc/dcmitype/": "dctypes"
    
        types =
          "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": "item"
          "http://www.w3.org/ns/openannotation/core/hasMotivation": "item"
    
        Manifest.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Data.Manifest", args..., (that) ->
            options = that.options
    
            data = MITHgrid.Data.Store.initInstance()
    
            that.size = -> data.size()
            
            importer = MITHgrid.Data.Importer.RDF_JSON.initInstance data, NS, types
    
            loadedUrls = []
    
            importFromURL = (url, cb) ->
              if url in loadedUrls
                cb()
                return
              loadedUrls.push url
              that.addItemsToProcess 1
              
              $.ajax
                url: url
                type: 'GET'
                contentType: 'application/rdf+json'
                processData: false
                dataType: 'json'
                success: (data) ->
                  that.addItemsProcessed 1
                  that.importJSON data, cb
                error: (e) -> 
                  that.addItemsProcessed 1
                  throw new Error("Could not load the manifest")
    
            # we want to get the rdf/JSON version of things if we can
            that.importJSON = (json, cb) ->
              # we care about certain namespaces - others we ignore
              # those we care about, we translate for datastore
              # {nsPrefix}{localName}
              syncer = MITHgrid.initSynchronizer cb
              syncer.increment()
              importer.import json, (ids) ->
                #
                # If the manifest indicates that another document describes
                # this resource, then we load the data before continuing
                # processing for this resource.
                #
     
                # we want anything that has the oreisDescribedBy property
                idset = MITHgrid.Data.Set.initInstance ids
                urls = data.getObjectsUnion(idset, 'oreisDescribedBy')
                
                urls.visit (url) ->
                  syncer.increment()
                  importFromURL url, syncer.decrement
                syncer.decrement()
              syncer.done()
    
            itemsWithType = (type) ->
              type = [ type ] if !$.isArray(type)
              types = MITHgrid.Data.Set.initInstance type
              data.getSubjectsUnion(types, "type").items()
    
            itemsForCanvas = (canvas) ->
              # Given a canvas, find the the TEI XML URL
              canvas = [ canvas ] if !$.isArray(canvas)
              canvasSet = MITHgrid.Data.Set.initInstance(canvas)
              specificResources = data.getSubjectsUnion(canvasSet, "oahasSource")
              imageAnnotations = data.getSubjectsUnion(canvasSet, "oahasTarget")            
              contentAnnotations = data.getSubjectsUnion(specificResources, "oahasTarget")
              tei = data.getObjectsUnion(contentAnnotations, 'oahasBody')
              teiURL = data.getObjectsUnion(tei, 'oahasSource')
    
              # Now find all annotations targeting that XML URL
              specificResourcesAnnos = data.getSubjectsUnion(teiURL, 'oahasSource')
              annos = data.getSubjectsUnion(specificResourcesAnnos, 'oahasTarget').items()
    
              # Append other annotations collected so far and return
              return annos.concat imageAnnotations.items(), contentAnnotations.items()
    
            flushSearchResults = ->
              types = MITHgrid.Data.Set.initInstance ['sgaSearchAnnotation']
              searchResults = data.getSubjectsUnion(types, "type").items()
              data.removeItems searchResults
    
            #
            # Get things of different types. For example, "scCanvas" gets
            # all of the canvas items.
            #
            that.getCanvases    = -> itemsWithType 'scCanvas'
            that.getZones       = -> itemsWithType 'scZone'
            that.getSequences   = -> itemsWithType 'scSequence'
            that.getAnnotations = -> itemsWithType 'oaAnnotation'
            that.getAnnotationsForCanvas = itemsForCanvas
            that.flushSearchResults = flushSearchResults
    
            that.getItem = data.getItem
            that.contains = data.contains
    
            that.importFromURL = (url, cb) ->
              importFromURL url, ->
                cb() if cb?

    # # Presentations
    SGAReader.namespace "Presentation", (Presentation) ->
    
      #
      # ## Presentation.TextContent
      #
    
      #
      # The TextContent presentation is all about modeling a section of a canvas
      # as a textual zone instead of a pixel-based zone. Eventually, we may want
      # to allow addressing of lines and character offsets, but for now we simply
      # fill in the area with textual annotations in the dataView.
      #
    
      Presentation.namespace "TextContent", (TextContent) ->
        TextContent.initInstance = (args...) ->
          MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.TextContent", args..., (that, container) ->
            options = that.options
    
            #
            # We draw each text span type the same way. We rely on the
            # item.type to give us the CSS classes we need for the span
            #
            annoLens = (container, view, model, id) ->
              rendering = {}
              el = $("<span></span>")
              rendering.$el = el
              item = model.getItem id
              el.text item.text[0]
              el.addClass item.type.join(" ")
              el.attr "style", item.css?[0]
              $(container).append el
              rendering.remove = ->
                el.remove()
              rendering.update = (item) ->
                el.text item.text[0]
              rendering
    
            #
            # We expect an HTML container for this to which we can append
            # all of the text content pieces that belong to this container.
            # For now, we are dependent on the data store to retain the ordering
            # of items based on insertion order. Eventually, we'll build
            # item ordering into the basic MITHgrid presentation code. Then, we
            # can set 
            #
            that.addLens 'AdditionAnnotation', annoLens
            that.addLens 'DeletionAnnotation', annoLens
            that.addLens 'SearchAnnotation', annoLens
            that.addLens 'LineAnnotation', annoLens
            that.addLens 'Text', annoLens
    
            #
            # Line breaks are different. We just want to add an explicit
            # break without any classes or styling.
            #
            that.addLens 'LineBreak', (container, view, model, id) ->
              rendering = {}
              el = $("<br/>")
              rendering.$el = el
              $(container).append(el)
    
              rendering.remove = -> el.remove()
              rendering.update = (item) ->
    
              rendering
    
      #
      # ## Presentation.Zone
      #
    
      #
      # The Zone presentation handles mapping annotations onto an SVG
      # surface. A Canvas is just a special zone that covers the entire canvas.
      #
      # We expect container to be in the SVG image.
      #
      Presentation.namespace "Zone", (Zone) ->
        Zone.initInstance = (args...) ->
          MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.Zone", args..., (that, container) ->
            options = that.options
            svgRoot = options.svgRoot
    
            #
            # !target gives us all of the annotations that target the given
            # item id. We use this later to find all of the annotations that target
            # a given zone.
            #
            annoExpr = that.dataView.prepare(['!target'])
    
            #
            # Since images don't have annotations attached to them, we simply
            # do nothing if our presentation root isn't marked as including
            # images.
            #
            that.addLens 'Image', (container, view, model, id) ->
              return unless 'Image' in (options.types || [])
              rendering = {}
    
              item = model.getItem id
    
              # If the viewbox has been removed because of the image viewer, restore it.
              svg = $(svgRoot.root())
              # jQuery won't modify the viewBox - using pure JS
              vb = svg.get(0).getAttribute("viewBox")
    
              if !vb?
                svgRoot.configure
                  viewBox: "0 0 #{options.width} #{options.height}"
    
              svgImage = null
              renderImage = (item) ->
                if item.image?[0]? and svgRoot?
                  x = if item.x?[0]? then item.x[0] else 0
                  y = if item.y?[0]? then item.y[0] else 0
                  width = if item.width?[0]? then item.width[0] else options.width - x
                  height = if item.height?[0]? then item.height[0] else options.height - y
                  if svgImage?
                    svgRoot.remove svgImage
                  svgImage = svgRoot.image(container, x, y, width, height, item.image?[0], {
                    preserveAspectRatio: 'none'
                  })
    
              renderImage(item)
    
              rendering.update = renderImage
    
              rendering.remove = ->
                if svgImage? and svgRoot?
                  svgRoot.remove svgImage
              rendering
    
            that.addLens 'ImageViewer', (container, view, model, id) ->
              return unless 'Image' in (options.types || [])
              rendering = {}
    
              item = model.getItem id
    
              app = that.options.application()
    
              # Activate imageControls
              app.imageControls.setActive(true)
              
              # Djatoka URL is now hardcoded, it will eventually come from the manifest
              # when we figure out how to model it.
              djatokaURL = "http://sga.mith.org:8080/adore-djatoka/resolver" 
              imageURL = item.image[0]
              baseURL = djatokaURL + "?url_ver=Z39.88-2004&rft_id=" + imageURL
    
              po = org.polymaps
    
              # clean up svg root element to accommodate Polymaps.js
              svg = $(svgRoot.root())
              # jQuery won't modify the viewBox - using pure JS
              svg.get(0).removeAttribute("viewBox")
    
              g = svgRoot.group()
    
              map = po.map()
                .container(g)
    
              canvas = $(container).parent().get(0)
    
              toAdoratio = $.ajax
                datatype: "json"
                url: baseURL + '&svc_id=info:lanl-repo/svc/getMetadata'
                success: adoratio(canvas, baseURL, map)
    
              # wait for polymap to load image and update map, then...
              toAdoratio.then ->
                # Help decide when to propagate changes...
                fromZoomControls = false
                # Keep track of some start values
                startCenter = map.center()
    
                # Add listeners for external controls
                app.imageControls.events.onZoomChange.addListener (z) ->
                  map.zoom(z)
                  app.imageControls.setImgPosition map.position
                  fromZoomControls = true
                  
                app.imageControls.events.onImgPositionChange.addListener (p) ->
                  # only apply if reset
                  if p.topLeft.x == 0 and p.topLeft.y == 0
                    map.center(startCenter)
    
                # Update controls with zoom and position info:
                # both at the beginning and after every change.
                app.imageControls.setZoom map.zoom()
                app.imageControls.setMaxZoom map.zoomRange()[1]
                app.imageControls.setMinZoom map.zoomRange()[0]
                app.imageControls.setImgPosition map.position
                
                map.on 'zoom', ->
                  if !fromZoomControls
                    app.imageControls.setZoom map.zoom()
                    app.imageControls.setImgPosition map.position                
                    app.imageControls.setMaxZoom map.zoomRange()[1]
                  fromZoomControls = false
                map.on 'drag', ->
                  app.imageControls.setImgPosition map.position
    
              
              rendering.update = (item) ->
                0 # do nothing for now - eventually, update image viewer?
    
              rendering.remove = ->
                app.imageControls.setActive(false)
                app.imageControls.setZoom(0)
                app.imageControls.setMaxZoom(0)
                app.imageControls.setMinZoom(0)
                app.imageControls.setImgPosition 
                  topLeft:
                    x: 0,
                    y: 0,
                  bottomRight:
                    x: 0,
                    y: 0
                $(svgRoot.root()).find('#map').remove()
    
              rendering
    
            #
            # ZoneAnnotations just map a zone onto a zone or canvas. We render
            # these regardless of what kinds of annotations we are displaying
            # since we might eventually get to an annotation we want to display.
            #
            that.addLens 'ZoneAnnotation', (container, view, model, id) ->
              rendering = {}
    
              zoneInfo = model.getItem id
              zoneContainer = null
              zoneContainer = document.createElementNS('http://www.w3.org/2000/svg', 'svg' )
              # pull start/end/width/height from constraint with a default of
              # the full surface
              x = if item.x?[0]? then item.x[0] else 0
              y = if item.y?[0]? then item.y[0] else 0
              width = if item.width?[0]? then item.width[0] else options.width - x
              height = if item.height?[0]? then item.height[0] else options.height - y
              $(zoneContainer).attr("x", x).attr("y", y).attr("width", width).attr("height", height)
              container.appendChild(zoneContainer)
    
              # TODO: position/size zoneContainer and set scaling.
              zoneDataView = MITHgrid.Data.SubSet.initInstance
                dataStore: model
                expressions: [ '!target' ]
                #key: id
    
              zone = Zone.initInstance zoneContainer,
                types: options.types
                dataView: zoneDataView
                svgRoot: svgRoot
                application: options.application
                heigth: height
                width: width
    
              zoneDataView.setKey id
    
              rendering._destroy = ->
                zone._destroy() if zone._destroy?
                zoneDataView._destroy() if zoneDataView._destroy?
    
              rendering.remove = ->
                rendering._destroy()
     
              rendering.update = (item) ->
                x = if item.x?[0]? then item.x[0] else 0
                y = if item.y?[0]? then item.y[0] else 0
                width = if item.width?[0]? then item.width[0] else options.width - x
                height = if item.height?[0]? then item.height[0] else options.height - y
                $(zoneContainer).attr("x", x).attr("y", y).attr("width", width).attr("height", height)
     
              rendering
    
            #
            # A ContentAnnotation is just text placed on the canvas. No
            # structure. This is the default mode for SharedCanvas.
            #
            # See the following TextContentZone lens for how we're managing
            # the SVG/HTML interface.
            #
    
            that.addLens 'ContentAnnotation', (container, view, model, id) ->
              return unless 'Text' in (options.types || [])
    
              rendering = {}
              item = model.getItem id
    
              textContainer = document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject')
    
              x = if item.x?[0]? then item.x[0] else 0
              y = if item.y?[0]? then item.y[0] else 0
              width = if item.width?[0]? then item.width[0] else options.width - x
              height = if item.height?[0]? then item.height[0] else options.height - y
              $(textContainer).attr("x", x).attr("y", y).attr("width", width).attr("height", height)
              container.appendChild(textContainer)
              bodyEl = document.createElementNS('http://www.w3.org/1999/xhtml', 'body')
              rootEl = document.createElement('div')
              $(rootEl).addClass("text-content")
              
              rootEl.text(item.text[0])
              rendering.update = (item) ->
                rootEl.text(item.text[0])
              rendering.remove = ->
                rootEl.remove()
              rendering
    
            #
            #
            # We're rendering text content from here on down, so if we aren't
            # rendering text for this view, then we shouldn't do anything here.
            #
            # N.B.: If we ever support showing images based on their place
            # in the text, then we will need to treat this like we treat the
            # Zone above and allow rendering of embedded zones even if we don't
            # render the textual content.
            #
            that.addLens 'TextContentZone', (container, view, model, id) ->
              return unless 'Text' in (options.types || [])
    
              # Set initial viewbox
              svg = $(svgRoot.root())
              # jQuery won't modify the viewBox - using pure JS
              vb = svg.get(0).getAttribute("viewBox")
    
              if !vb?
                svgRoot.configure
                  viewBox: "0 0 #{options.width} #{options.height}"
    
              rendering = {}
              
              app = options.application()
              zoom = app.imageControls.getZoom()
    
              item = model.getItem id
     
              #
              # The foreignObject element MUST be in the SVG namespace, so we
              # can't use the jQuery convenience methods.
              #
    
              textContainer = null
              textContainer = document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject' )
    
              #
              # If we're not given an offset and size, then we assume that we're
              # covering the entire targeted zone or canvas.
              #
              x = if item.x?[0]? then item.x[0] else 0
              y = if item.y?[0]? then item.y[0] else 0
              width = if item.width?[0]? then item.width[0] else options.width - x
              height = if item.height?[0]? then item.height[0] else options.height - y
              $(textContainer).attr("x", x).attr("y", y).attr("width", width).attr("height", height)
              container.appendChild(textContainer)
    
              #
              # Similar to foreignObject, the body element MUST be in the XHTML
              # namespace, so we can't use jQuery. Once we're inside the body
              # element, we can use jQuery all we want.
              #
              bodyEl = document.createElementNS('http://www.w3.org/1999/xhtml', 'body')
              rootEl = document.createElement('div')
              $(rootEl).addClass("text-content")
              $(rootEl).attr("id", id)
              $(rootEl).css("font-size", 150)
              $(rootEl).css("line-height", 1.15)
              bodyEl.appendChild(rootEl)
              textContainer.appendChild(bodyEl)
    
              if app.imageControls.getActive()
                # If the marquee already exists, replace it with a new one.
                $('.marquee').remove()
                # First time, always full extent in size and visible area
                strokeW = 5
                marquee = svgRoot.rect(0, 0, Math.max(1, options.width-strokeW), Math.max(1, options.height-strokeW),
                  class : 'marquee' 
                  fill: 'yellow', 
                  stroke: 'navy', 
                  strokeWidth: strokeW,
                  fillOpacity: '0.05',
                  strokeOpacity: '0.9' #currently not working in firefox
                  ) 
                scale = options.width / $(container).width()
                visiblePerc = 100
                
                app.imageControls.events.onZoomChange.addListener (z) ->
                  if app.imageControls.getMaxZoom() > 0
    
                    width  = Math.round(options.width / Math.pow(2, (app.imageControls.getMaxZoom() - z)))              
                    visiblePerc = Math.min(100, ($(container).width() * 100) / width)
    
                    marquee.setAttribute("width", (options.width * visiblePerc) / 100 )
                    marquee.setAttribute("height", (options.height * visiblePerc) / 100 )
    
                    if app.imageControls.getZoom() > app.imageControls.getMaxZoom() - 1
                      $(marquee).attr "opacity", "0"
                    else
                      $(marquee).attr "opacity", "100"
    
                app.imageControls.events.onImgPositionChange.addListener (p) ->
                  marquee.setAttribute("x", ((-p.topLeft.x * visiblePerc) / 100) * scale)
                  marquee.setAttribute("y", ((-p.topLeft.y * visiblePerc) / 100) * scale)
    
              #
              # textDataView gives us all of the annotations targeting this
              # text content annotation - that is, all of the highlights and such
              # that change how we render the text mapped onto the zone/canvas.
              # We don't set the key here because the SubSet data view won't use
              # the key to filter the set of annotations during the initInstance
              # call.
              #
              textDataView = MITHgrid.Data.SubSet.initInstance
                dataStore: model
                expressions: [ '!target' ]
    
              #
              # Here we embed the text-based zone within the pixel-based
              # zone. Any text-based positioning will have to be handled by
              # the TextContent presentation.
              #
              text = Presentation.TextContent.initInstance rootEl,
                types: options.types
                dataView: textDataView
                svgRoot: svgRoot
                application: options.application
                height: height
                width: width
    
              #
              # Once we have the presentation in place, we set the
              # key of the SubSet data view to the id of the text content 
              # annotation item. This causes the presentation to render the
              # annotations.
              #
              textDataView.setKey id
    
              rendering._destroy = ->
                text._destroy() if text._destroy?
                textDataView._destroy() if textDataView._destroy?
    
              rendering.remove = ->
                $(textContainer).empty()
                svgRoot.remove textContainer
    
              rendering.update = (item) ->
                x = if item.x?[0]? then item.x[0] else 0
                y = if item.y?[0]? then item.y[0] else 0
                width = if item.width?[0]? then item.width[0] else options.width - x
                height = if item.height?[0]? then item.height[0] else options.height - y
                $(textContainer).attr("x", x).attr("y", y).attr("width", width).attr("height", height)
    
              rendering
    
      #
      # ## Presentation.Canvas
      #
    
      #
      # This is the wrapper around a root Zone presentation that gets things
      # started.
      #
      Presentation.namespace "Canvas", (Canvas) ->
        Canvas.initInstance = (args...) ->
          MITHgrid.Presentation.initInstance "SGA.Reader.Presentation.Canvas", args..., (that, container) ->
            # We want to draw everything that annotates a Canvas
            # this would be anything with a target = the canvas
            options = that.options
    
            # we need a nice way to get the span of text from the tei
            # and then we apply any annotations that modify how we display
            # the text before we create the svg elements - that way, we get
            # things like line breaks
    
            annoExpr = that.dataView.prepare(['!target'])
    
            pendingSVGfctns = []
            SVG = (cb) ->
              pendingSVGfctns.push cb
    
            svgRootEl = $("""
              <svg xmlns="http://www.w3.org/2000/svg" version="1.1"
                   xmlns:xlink="http://www.w3.org/1999/xlink"
                   width="0" height="0"
               >
              </svg>
            """)
            container.append(svgRootEl)
            svgRoot = $(svgRootEl).svg 
              onLoad: (svg) ->
                SVG = (cb) -> cb(svg)
                cb(svg) for cb in pendingSVGfctns
                pendingSVGfctns = null
            canvasWidth = null
            canvasHeight = null
            SVGHeight = null
            SVGWidth = parseInt($(container).width()*20/20, 10)
    
            #
            # MITHgrid makes available a global listener for browser window
            # resizing so we don't have to guess how to do this for each
            # application.
            #
            MITHgrid.events.onWindowResize.addListener ->
              SVGWidth = parseInt($(container).width() * 20/20, 10)
              if canvasWidth? and canvasWidth > 0
                that.setScale (SVGWidth / canvasWidth)
              
    
            that.events.onScaleChange.addListener (s) ->
              if canvasWidth? and canvasHeight?
                SVGHeight = parseInt(canvasHeight * s, 10)
                SVG (svgRoot) ->
                  svgRootEl.attr
                    width: canvasWidth
                    height: canvasHeight
    
                  # If the viewbox is not set (ie beacuse of an image viewer), 
                  # don't attempt to adjust it.
                  svg = $(svgRoot.root())
                  # jQuery won't modify the viewBox - using pure JS
                  vb = svg.get(0).getAttribute("viewBox")
    
                  if vb?
                    svgRoot.configure
                      viewBox: "0 0 #{canvasWidth} #{canvasHeight}"
    
                  svgRootEl.css
                    width: SVGWidth
                    height: SVGHeight
                    border: "0.5em solid #eeeeee"
                    "border-radius": "5px"
                    "background-color": "#ffffff"
    
            # the data view is managed outside the presentation
            dataView = MITHgrid.Data.SubSet.initInstance
              dataStore: options.dataView
              expressions: [ '!target' ]
              key: null
    
            realCanvas = null
    
            that.events.onCanvasChange.addListener (canvas) ->
              dataView.setKey(canvas)
              item = dataView.getItem canvas
              # now make SVG canvas the size of the canvas (for now)
              # eventually, we'll constrain the size but maintain the
              # aspect ratio
              canvasWidth = item.width?[0] || 1
              canvasHeight = item.height?[0] || 1
              that.setScale (SVGWidth / canvasWidth)
              if realCanvas?
                realCanvas.hide() if realCanvas.hide?
                realCanvas._destroy() if realCanvas._destroy?
              SVG (svgRoot) ->
                svgRoot.clear()
                realCanvas = SGA.Reader.Presentation.Zone.initInstance svgRoot.root(),
                  types: options.types
                  dataView: dataView
                  application: options.application
                  height: canvasHeight
                  width: canvasWidth
                  svgRoot: svgRoot
    

    # # Data Managment
    SGAReader.namespace "Data", (Data) ->
    
      #
      # ## Data.StyleStore
      #
    
      Data.namespace "StyleStore", (StyleStore) ->
        StyleStore.initInstance = (args...) ->
          MITHgrid.initInstance args..., (that) ->
            options = that.options
    
            docs = { }
            regex = new RegExp("(?:\\.(\\S+)\\s*\\{\\s*([^}]*)\\s*\\})", "mg")
    
            #
            # Associates the CSS content with the given id.
            #
            that.addStyles = (id, css) ->
              return if docs[id]?
              docs[id] = { }
              results = regex.exec(css)
              while results?.index?
                docs[id][results[1]] = results[2]
                results = regex.exec(css)
    
            #
            # Returns the CSS style rules for a given class as defined by the
            # CSS content associated with the given id.
            #
            that.getStylesForClass = (id, klass) ->
              if docs[id]?[klass]?
                docs[id][klass]
              else
                ""
    
      #
      # ## Data.TextStore
      #
      Data.namespace "TextStore", (TextStore) ->
        TextStore.initInstance = (args...) ->
          MITHgrid.initInstance args..., (that) ->
            options = that.options
    
            fileContents = { }
            loadingFiles = { }
            pendingFiles = { }
    
            that.addFile = (files) ->
              files = [ files ] unless $.isArray(files)
              for file in files 
                do (file) ->
                  if file? and !fileContents[file]? and !loadingFiles[file]?
                    loadingFiles[file] = [ ]
                    $.ajax
                      url: file
                      type: 'GET'
                      processData: false
                      success: (data) ->
                        c = data.documentElement.textContent
                        fileContents[file] = c
                        f(c) for f in loadingFiles[file]
                        delete loadingFiles[file]
    
            that.withFile = (file, cb) ->
              if fileContents[file]?
                cb(fileContents[file])
              else if loadingFiles[file]?
                loadingFiles[file].push cb
              else
                that.addFile file
                loadingFiles[file].push cb
    
      #
      # ## Data.Manifest
      #
      Data.namespace "Manifest", (Manifest) ->
    
        #
        # We list all of the namespaces that we care about and the prefix
        # we map them to. Some of the namespaces are easy "misspellings"
        # that let us support older namespaces.
        #
        NS =
          "http://dms.stanford.edu/ns/": "sc"
          "http://www.shared-canvas.org/ns/": "sc"
          "http://www.w3.org/2000/01/rdf-schema#": "rdfs"
          "http://www.w3.org/1999/02/22-rdf-syntax-ns#": "rdf"
          "http://www.w3.org/2003/12/exif/ns#": "exif"
          "http://purl.org/dc/elements/1.1/": "dc"
          "http://www.w3.org/ns/openannotation/core/": "oa"
          "http://www.openannotation.org/ns/": "oa"
          "http://www.w3.org/ns/openannotation/extension/": "oax"
          "http://www.openarchives.org/ore/terms/": "ore"
          "http://www.shelleygodwinarchive.org/ns/1#": "sga"
          "http://www.shelleygodwinarchive.org/ns1#": "sga"
          "http://www.w3.org/2011/content#": "cnt"
          "http://purl.org/dc/dcmitype/": "dctypes"
    
        types =
          "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": "item"
          "http://www.w3.org/ns/openannotation/core/hasMotivation": "item"
    
        Manifest.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Data.Manifest", args..., (that) ->
            options = that.options
    
            data = MITHgrid.Data.Store.initInstance()
    
            that.size = -> data.size()
            
            importer = MITHgrid.Data.Importer.RDF_JSON.initInstance data, NS, types
    
            loadedUrls = []
    
            importFromURL = (url, cb) ->
              if url in loadedUrls
                cb()
                return
              loadedUrls.push url
              that.addItemsToProcess 1
              
              $.ajax
                url: url
                type: 'GET'
                contentType: 'application/rdf+json'
                processData: false
                dataType: 'json'
                success: (data) ->
                  that.addItemsProcessed 1
                  that.importJSON data, cb
                error: (e) -> 
                  that.addItemsProcessed 1
                  throw new Error("Could not load the manifest")
    
            # we want to get the rdf/JSON version of things if we can
            that.importJSON = (json, cb) ->
              # we care about certain namespaces - others we ignore
              # those we care about, we translate for datastore
              # {nsPrefix}{localName}
              syncer = MITHgrid.initSynchronizer cb
              syncer.increment()
              importer.import json, (ids) ->
                #
                # If the manifest indicates that another document describes
                # this resource, then we load the data before continuing
                # processing for this resource.
                #
     
                # we want anything that has the oreisDescribedBy property
                idset = MITHgrid.Data.Set.initInstance ids
                urls = data.getObjectsUnion(idset, 'oreisDescribedBy')
                
                urls.visit (url) ->
                  syncer.increment()
                  importFromURL url, syncer.decrement
                syncer.decrement()
              syncer.done()
    
            itemsWithType = (type) ->
              type = [ type ] if !$.isArray(type)
              types = MITHgrid.Data.Set.initInstance type
              data.getSubjectsUnion(types, "type").items()
    
            itemsForCanvas = (canvas) ->
              # Given a canvas, find the the TEI XML URL
              canvas = [ canvas ] if !$.isArray(canvas)
              canvasSet = MITHgrid.Data.Set.initInstance(canvas)
              specificResources = data.getSubjectsUnion(canvasSet, "oahasSource")
              imageAnnotations = data.getSubjectsUnion(canvasSet, "oahasTarget")            
              contentAnnotations = data.getSubjectsUnion(specificResources, "oahasTarget")
              tei = data.getObjectsUnion(contentAnnotations, 'oahasBody')
              teiURL = data.getObjectsUnion(tei, 'oahasSource')
    
              # Now find all annotations targeting that XML URL
              specificResourcesAnnos = data.getSubjectsUnion(teiURL, 'oahasSource')
              annos = data.getSubjectsUnion(specificResourcesAnnos, 'oahasTarget').items()
    
              # Append other annotations collected so far and return
              return annos.concat imageAnnotations.items(), contentAnnotations.items()
    
            flushSearchResults = ->
              types = MITHgrid.Data.Set.initInstance ['sgaSearchAnnotation']
              searchResults = data.getSubjectsUnion(types, "type").items()
              data.removeItems searchResults
    
            #
            # Get things of different types. For example, "scCanvas" gets
            # all of the canvas items.
            #
            that.getCanvases    = -> itemsWithType 'scCanvas'
            that.getZones       = -> itemsWithType 'scZone'
            that.getSequences   = -> itemsWithType 'scSequence'
            that.getAnnotations = -> itemsWithType 'oaAnnotation'
            that.getAnnotationsForCanvas = itemsForCanvas
            that.flushSearchResults = flushSearchResults
    
            that.getItem = data.getItem
            that.contains = data.contains
    
            that.importFromURL = (url, cb) ->
              importFromURL url, ->
                cb() if cb?

    # # Components
    
    SGAReader.namespace "Component", (Component) ->
    
      #
      # ## Component.ProgressBar
      #
    
      Component.namespace "ProgressBar", (ProgressBar) ->
    
        #
        # This component manages the display of a progress bar based on
        # the Twitter Bootstrap progress bar component.
        #
        # The component has two variables: Numerator and Denominator.
        #
    
        ProgressBar.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Component.ProgressBar", args..., (that, container) ->
    
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
    
      Component.namespace "Spinner", (Spinner) ->
    
        Spinner.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Component.Spinner", args..., (that, container) ->
    
            that.show = -> 
              $(container).show()
    
            that.hide = -> 
              $(container).hide()
    
      #
      # ## Component.SequenceSelector
      #
    
      Component.namespace "SequenceSelector", (SequenceSelector) ->
    
        #
        # This component manages the options of a select HTML form element.
        # 
        # The component has one variable: Sequence.
        #
        # The container should be a <select></select> element.
        #
    
        SequenceSelector.initInstance = (args...) ->
          MITHgrid.Presentation.initInstance "SGA.Reader.Component.SequenceSelector", args..., (that, container) ->
            options = that.options
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
    
            that.events.onSequenceChange.addListener (v) ->
              $(container).val(v)
    
            that.finishDisplayUpdate = ->
              that.setSequence $(container).val()
    
      #
      # ## Component.Slider
      #
    
      Component.namespace "Slider", (Slider) ->
    
        #
        # This component manages an HTML5 slider input element.
        #
        # This component has three variables: Min, Max, and Value.
        #
        Slider.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Component.Slider", args..., (that, container) ->
            that.events.onMinChange.addListener (n) ->
              $(container).attr
                min: n
            that.events.onMaxChange.addListener (n) ->
              $(container).attr
                max: n
            that.events.onValueChange.addListener (n) -> 
              $(container).val(n)
              $.bbq.pushState
                n: that.getValue()+1
            $(container).change (e) -> that.setValue $(container).val()
    
      #
      # ## Component.PagerControls
      #
    
      Component.namespace "PagerControls", (PagerControls) ->
    
        #
        # This component manages a set of Twitter Bootstrap buttons that display
        # the step forward, step backward, fast forward, and fast backward icons.
        #
        # This component has three variables: Min, Max, and Value.
        #
    
        PagerControls.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Component.PagerControls", args..., (that, container) ->
            
            $(window).bind "hashchange", (e) ->
              n = $.bbq.getState "n" 
              that.setValue n-1
    
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
                lastEl.removeClass "disabled"
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
    
            updateBBQ = ->
              $.bbq.pushState
                n: that.getValue()+1
    
            $(prevEl).click (e) ->
              e.preventDefault()
              that.addValue -1
              updateBBQ()
            $(nextEl).click (e) ->
              e.preventDefault()
              that.addValue 1
              updateBBQ()
            $(firstEl).click (e) ->
              e.preventDefault()
              that.setValue that.getMin()
              updateBBQ()
            $(lastEl).click (e) ->
              e.preventDefault()
              that.setValue that.getMax()
              updateBBQ()
    
      #
      # ## Component.ImageControls
      #
      Component.namespace "ImageControls", (ImageControls) ->
        ImageControls.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Component.ImageControls", args..., (that, container) ->        
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
    
      #
      # ## Component.SearchBox
      #
      Component.namespace "SearchBox", (SearchBox) ->
        SearchBox.initInstance = (args...) ->
          MITHgrid.initInstance "SGA.Reader.Component.SearchBox", args..., (that, service) ->        
            container = args[0]
            that.setServiceURL service
    
            # console.log $(container).closest('form')
    
            $(container).closest('form').submit (e) ->
              e.preventDefault()
              val = $(container).val()
              if !val.match '^\s*$'
                that.setQuery val
              false
              
    
            # On submit function go here and they will simply change the variable Query
    # # Controllers

    # # Core Utilities

    # # Application
    
    SGAReader.namespace "Application", (Application) ->
      #
      # ## Application.SharedCanvas
      #
      Application.namespace "SharedCanvas", (SharedCanvas) ->
        SharedCanvas.initInstance = (args...) ->
          MITHgrid.Application.initInstance "SGA.Reader.Application.SharedCanvas", args..., (that) ->
            options = that.options
    
            #
            # ### Presentation Coordination
            #
    
            presentations = []
    
            # This is a convenience method for creating a Shared Canvas
            # presentation and tying it to the data management application.
            # All presentations linked to this application will be coordinated
            # when the current sequence or canvas changes.
            #
            that.addPresentation = (config) ->
              p = SGA.Reader.Presentation.Canvas.initInstance config.container,
                types: config.types
                application: -> that
                dataView: that.dataView.canvasAnnotations
              presentations.push [ p, config.container ]
    
            #
            # When we change the sequence, we find out where our current
            # canvas is in the new sequence and set the position to reflect
            # the new relationship between the canvas and the current sequence.
            #
            currentSequence = null
    
            that.events.onSequenceChange.addListener (s) ->
              currentSequence = s
              seq = that.dataStore.data.getItem currentSequence
    
              hash = $.param.fragment window.location.href
              paras = $.deparam hash
              
              n = parseInt(paras.n)
              if paras.n? and seq.sequence.length >= n-1 >= 0
                p = n-1
              else
                if seq?.sequence?
                  p = seq.sequence.indexOf that.getCanvas()
                p = 0 if p < 0
    
              that.setPosition p
                
            #
            # The position lets us manage our path through a sequence without
            # having to know the names of the canvases.
            #
            that.events.onPositionChange.addListener (p) ->
              seq = that.dataStore.data.getItem currentSequence
              canvasKey = seq.sequence?[p]
              that.setCanvas canvasKey    
    
            #
            # But if we do know the name of the canvas we want to see, we
            # can switch to it and everything else will be kept in sync as
            # long as the canvas is in the current sequence.
            #
            that.events.onCanvasChange.addListener (k) ->
              that.dataView.canvasAnnotations.setKey k
              seq = that.dataStore.data.getItem currentSequence
              p = seq.sequence.indexOf k
              if p >= 0 && p != that.getPosition()
                that.setPosition p
              Q.fcall(that.loadCanvas, k).then () -> 
                  pp[0].setCanvas k for pp in presentations
              k
    
            #
            # ### Manifest Import
            #
    
            #
            # manifestData holds the data read from the shared canvas
            # manifest that we then process into the application's data store.
            #
            manifestData = SGA.Reader.Data.Manifest.initInstance()
    
            #
            # We expose several of the manifestData methods so that things like
            # the progress bar can know where we are in the process.
            #
            that.events.onItemsProcessedChange = manifestData.events.onItemsProcessedChange
            that.events.onItemsToProcessChange = manifestData.events.onItemsToProcessChange
            that.getItemsProcessed = manifestData.getItemsProcessed
            that.getItemsToProcess = manifestData.getItemsToProcess
            that.setItemsProcessed = manifestData.setItemsProcessed
            that.setItemsToProcess = manifestData.setItemsToProcess
            that.addItemsProcessed = manifestData.addItemsProcessed
            that.addItemsToProcess = manifestData.addItemsToProcess
            that.addManifestData = manifestData.importFromURL
            that.getAnnotationsForCanvas = manifestData.getAnnotationsForCanvas
            that.flushSearchResults = manifestData.flushSearchResults
    
            #
            # textSource manages fetching and storing all of the TEI
            # files that we will be referencing in our text content
            # annotations.
            #
            textSource = SGA.Reader.Data.TextStore.initInstance()
    
            that.withSource = textSource.withFile
    
            extractSpatialConstraint = (item, id) ->
              return unless id?
              constraint = manifestData.getItem id
              if 'oaFragmentSelector' in constraint.type
                if constraint.rdfvalue[0].substr(0,5) == "xywh="
                  item.shape = "Rectangle"
                  bits = constraint.rdfvalue[0].substr(5).split(",")
                  item.x = parseInt(bits[0],10)
                  item.y = parseInt(bits[1],10)
                  item.width = parseInt(bits[2],10)
                  item.height = parseInt(bits[3],10)
              else
                if constraint.oaxbegin?
                  item.start = parseInt(constraint.oaxbegin?[0], 10)
                if constraint.oaxend?
                  item.end = parseInt(constraint.oaxend?[0], 10)
              # handle SVG constraints (rectangles, ellipses)
              # handle time constraints? for video/sound annotations?
    
            extractTextTarget = (item, id) ->
              return unless id?
              target = manifestData.getItem id
              if "oaSpecificResource" in target.type
                item.target = target.oahasSource
                if target.oahasStyle?
                  styleItem = manifestData.getItem target.oahasStyle[0]
                  if "text/css" in styleItem.dcformat
                    item.css = styleItem.cntchars
    
                extractSpatialConstraint(item, target.oahasSelector?[0])
              else
                item.target = id
    
            extractTextBody = (item, id) ->
              return unless id?
              body = manifestData.getItem id
              textSource.addFile(body.oahasSource)
              item.source = body.oahasSource
              extractSpatialConstraint(item, body.oahasSelector?[0])
    
            that.loadCanvas = (canvas, cb) ->
              deferred = Q.defer()
    
              items = []
              textSources = {}
              textAnnos = []
    
              syncer = MITHgrid.initSynchronizer()
    
              annos = manifestData.getAnnotationsForCanvas canvas
    
              that.addItemsToProcess annos.length
              syncer.process annos, (id) ->
                #
                # Once we have our various annotations, we want to process
                # them to produce sets of items that can be displayed in a
                # sequence. We preprocess overlapping ranges of highlights
                # to create non-overlapping multi-classed items that can
                # be filtered in the final presentation.
                #
                that.addItemsProcessed 1
                aitem = manifestData.getItem id
                array = null
                item =
                  id: id
    
                #
                # For now, we *assume* that the content annotation is coming
                # from a TEI file and is marked by begin/end pointers.
                # These annotations are loaded into the triple store as they
                # are since they don't target sub-ranges of text.
                # TextContent items end up acting like zones in that they
                # are the target of text annotations but don't themselves
                # end up providing content.
                #
                if "scContentAnnotation" in aitem.type
                  extractTextTarget item, aitem.oahasTarget?[0]
                  extractTextBody   item, aitem.oahasBody?[0]
                  if item.start? and item.end?
                    textSources[item.source] ?= []
                    textSources[item.source].push [ id, item.start, item.end ]
                  #
                  # We should use "ContentAnnotation" only when we know we
                  # won't have anything targeting this text. Otherwise, we
                  # should use TextContentZone. This is a work in progress
                  # as we see the pattern unfold.
                  #
                  # Essentially, if we want the annotation to act as a classic
                  # Shared Canvas text content annotation, we use a type of
                  # "ContentAnnotation". If we want to allow highlight annotation
                  # of the text with faceted selection of text, then we use a
                  # type of "TextContentZone".
                  #
                  if item.text?
                    item.type = "ContentAnnotation"
                  else
                    item.type = "TextContentZone"
                  array = items
    
                #
                # For now, we assume that images map onto the entire canvas.
                # This isn't true for Shared Canvas. We need to extract any
                # spatial constraint and respect it in the presentation.
                #
                else if "scImageAnnotation" in aitem.type
                  imgitem = manifestData.getItem aitem.oahasBody
                  imgitem = imgitem[0] if $.isArray(imgitem)
                  array = items
    
                  item.target = aitem.oahasTarget
                  item.label = aitem.rdfslabel
                  item.image = imgitem.oahasSource || aitem.oahasBody
                  item.type = "Image"
                  if "image/jp2" in imgitem["dcformat"] and that.imageControls?
                    item.type = "ImageViewer"
    
                else if "scZoneAnnotation" in aitem.type
                  target = manifestData.getItem aitem.oahasTarget
                  extractSpatialConstraint item, target.hasSelector?[0]
                  array = items
    
                  item.target = target.hasSource
                  item.label = aitem.rdfslabel
                  item.type = "ZoneAnnotation"
    
                else
                  #
                  # All of the SGA-specific annotations will have types
                  # prefixed with "sga" and ending in "Annotation"
                  sgaTypes = (f.substr(3) for f in aitem.type when f.substr(0,3) == "sga" and f.substr(f.length-10) == "Annotation")
                  if sgaTypes.length > 0
                    extractTextTarget item, aitem.oahasTarget?[0]
                    item.type = sgaTypes
                    array = textAnnos
    
                array.push item if item.type? and array?
    
              syncer.done ->
                # We process the highlight annotations here so we don't have
                # to do it *every* time we show a canvas.
                # each addition, deletion, etc., targets a scContentAnnotation
                # but we want to make sure we get any scContentAnnotation text
                # that isn't covered by any of the other annotations
    
                # This is inspired by NROFF as implemented, for example, in
                # [the Discworld mud.](https://github.com/Yuffster/discworld_distribution_mudlib/blob/master/obj/handlers/nroff.c)
                # It also has shades of a SAX processor thrown in.
                
                that.addItemsToProcess 1 + textAnnos.length
    
                that.dataStore.data.loadItems items, ->
                  items = []
                  modstart = {}
                  modend = {}
                  modInfo = {}
                  setMod = (item) ->
                    source = item.target
                    start = item.start
                    end = item.end
                    id = item.id
                    id = id[0] if $.isArray(id)
                    modInfo[id] = item
                    modstart[source] ?= {}
                    modstart[source][start] ?= []
                    modstart[source][start].push id
                    modend[source] ?= {}
                    modend[source][end] ?= []
                    modend[source][end].push id
    
                  setMod item for item in textAnnos
    
                  sources = (s for s of modstart)
                  that.addItemsToProcess sources.length
                  that.addItemsProcessed textAnnos.length
    
                  for source in sources
                    do (source) ->
                      that.withSource source, (text) ->
                        textItems = []
                        modIds = [ ]
                        br_pushed = false
    
                        pushTextItem = (classes, css, target, start, end) ->
                          textItems.push
                            type: classes
                            css: css.join(" ")
                            text: text[start ... end]
                            id: source + "-" + start + "-" + end
                            target: target
                            start: start
                            end: end
                        
                        processNode = (start, end) ->
                          classes = []
                          css = []
                          for id in modIds
                            classes.push modInfo[id].type
                            if $.isArray(modInfo[id].css)
                              css.push modInfo[id].css.join(" ")
                            else
                              css.push modInfo[id].css
    
                          classes.push "Text" if classes.length == 0
    
                          makeTextItems start, end, classes, css
    
                        #
                        # We run through each possible shared canvas
                        # target that might be mapped onto the source TEI
                        # via the TextContent annotation. We want to target
                        # the shared canvas text content zone, not the
                        # text source that the highlight is targeting in the
                        # actual open annotation model.
                        #
                        makeTextItems = (start, end, classes, css) ->
                          for candidate in (textSources[source] || [])
                            if start <= candidate[2] and end >= candidate[1]
                              s = Math.min(Math.max(start, candidate[1]),candidate[2])
                              e = Math.max(Math.min(end, candidate[2]), candidate[1])
                              pushTextItem classes, css, candidate[0], s, e
                          false
    
                        #
                        # A line break is just a zero-width annotation at
                        # the given position.
                        #
                        makeLinebreak = (pos) ->
                          classes = [ "LineBreak" ]
                          #classes.push modInfo[id].type for id in modIds
                          makeTextItems pos, pos, classes, [ "" ]
    
                        #
                        mstarts = modstart[source] || []
                        mends = modend[source] || []
                        last_pos = 0
                        positions = (parseInt(p,10) for p of mstarts).concat(parseInt(p,10) for p of mends).sort (a,b) -> a-b
                        for pos in positions
                          if pos != last_pos
                            processNode last_pos, pos
                            if br_pushed and !text.substr(last_pos, pos - last_pos).match(/^\s*$/)
                              br_pushed = false
                            needs_br = false
                            for id in (mstarts[pos] || [])
                              if "LineAnnotation" in modInfo[id].type
                                needs_br = true
                              modIds.push id
                            for id in (mends[pos] || [])
                              if "LineAnnotation" in modInfo[id].type
                                needs_br = true
                              idx = modIds.indexOf id
                              modIds.splice idx, 1 if idx > -1
                            if needs_br and not br_pushed
                              makeLinebreak pos
                              br_pushed = true
                            last_pos = pos
                        processNode last_pos, text.length
    
                        that.dataStore.data.loadItems textItems, ->
                          that.addItemsProcessed 1
                  
                  deferred.resolve()
                  that.addItemsProcessed 1
    
              if cb?
                cb()
    
              deferred.promise
    
            if options.url?
              #
              # If we're given a URL in our options, then go ahead and load
              # it. For now, this is the only way to get data from a manifest.
              #
              manifestData.importFromURL options.url, ->
                # Once the RDF/JSON is loaded from the url and parsed into
                # the manifestData triple store, we process it to pull out all
                # of the features we care about.
                items = []
                syncer = MITHgrid.initSynchronizer()
    
                #
                # We begin by pulling out all of the canvases defined in the
                # manifest. We only care about their id, size, and label.
                #
                canvases = manifestData.getCanvases()
                that.addItemsToProcess canvases.length
                syncer.process canvases, (id) ->
                  that.addItemsProcessed 1
                  mitem = manifestData.getItem id
                  items.push
                    id: id
                    type: 'Canvas'
                    width: parseInt(mitem.exifwidth?[0], 10)
                    height: parseInt(mitem.exifheight?[0], 10)
                    label: mitem.dctitle || mitem.rdfslabel
    
                #
                # We want to add any zones that might be in the manifest. These
                # are like canvases, but with the addition of a rotation angle.
                # ZoneAnnotations map zones onto canvases.
                #
                zones = manifestData.getZones()
                that.addItemsToProcess zones.length
                syncer.process zones, (id) ->
                  that.addItemsProcessed 1
                  zitem = manifestData.getItem id
                  items.push
                    id: id
                    type: 'Zone'
                    width: parseInt(mitem.exifwidth?[0], 10)
                    height: parseInt(mitem.exifheight?[0], 10)
                    angle: parseInt(mitem.scnaturalAngle?[0], 10) || 0
                    label: zitem.rdfslabel
    
                #
                # We pull out all of the sequences in the manifest. MITHgrid
                # stores a multi-valued property as an ordered list (JavaScript
                # array), so we don't need all of the blank nodes that RDF uses.
                #
                # The primary or initial sequence is undefined if there are
                # multiple sequences in the manifest.
                #
                seq = manifestData.getSequences()
                that.addItemsToProcess seq.length
                syncer.process seq, (id) ->
                  that.addItemsProcessed 1
                  sitem = manifestData.getItem id
                  item =
                    id: id
                    type: 'Sequence'
                    label: sitem.rdfslabel
    
                  seq = []
                  seq.push sitem.rdffirst[0]
                  sitem = manifestData.getItem sitem.rdfrest[0]
                  while sitem.id? # manifestData.contains(sitem.rdfrest?[0])
                    seq.push sitem.rdffirst[0]
                    sitem = manifestData.getItem sitem.rdfrest[0]
                  item.sequence = seq
                  items.push item           
    
                syncer.done ->
                  that.dataStore.data.loadItems items
    
        #
        # ### Application.SharedCanvas#builder
        #
        # This is an alternate instantiation method that will look through the
        # DOM and find elements with the given class and instantiate
        # Application.SharedCanvas applications for each manifest found along
        # with Presentation.Canvas presentations for each element.
        #
        # Options:
        #
        # * class - the CSS class of the elements (defaults to "canvas")
        # * progressTracker - a component with the setNumerator and
        #   setDenominator methods that can show progress to the user
        #
        SharedCanvas.builder = (config) ->
          that =
            manifests: {}
    
          manifestCallbacks = {}
    
          # Initialize these to nil functions in case we don't have a progress
          # tracker. Also makes sure that CoffeeScript scopes them correctly.
          updateProgressTracker = ->
          updateProgressTrackerVisibility = ->
    
          # Simple spinner as alternative to progress tracker
          updateSpinnerVisibility = ->
    
          if config.spinner?
            updateSpinnerVisibility = ->
              for m, obj of that.manifests
                tot = obj.getItemsToProcess()
                obj.events.onItemsToProcessChange.addListener (i) ->
                  config.spinner.hide() if i > tot
    
    
          if config.progressTracker?
            updateProgressTracker = ->
              # Go through and calculate all of the unfinished items. Then
              # update the progress tracker. Should work even if a builder
              # is tracking multiple manifests.
              n = 0
              d = 0
              for m, obj of that.manifests
                n += obj.getItemsProcessed()
                d += obj.getItemsToProcess()
              config.progressTracker.setNumerator(n)
              config.progressTracker.setDenominator(d or 1)
    
            uptv = null
            uptvTimer = 1000
    
            updateProgressTrackerVisibility = ->
              if uptv?
                uptvTimer = 500
              else
                uptv = ->
                  for m, obj of that.manifests
                    if obj.getItemsToProcess() > obj.getItemsProcessed()
                      config.progressTracker.show()
                      uptvTimer /= 2
                      uptvTimer = 500 if uptvTimer < 500
                      setTimeout uptv, uptvTimer
                      return
                  config.progressTracker.hide() if uptvTimer > 500
                  uptvTimer *= 2
                  uptvTimer = 10000 if uptvTimer > 10000
                  setTimeout uptv, uptvTimer
                uptv()
    
          if config.searchBox?
            if config.searchBox.getServiceURL()?
              config.searchBox.events.onQueryChange.addListener (q) ->
                queryURL = config.searchBox.getServiceURL() + q
                for m, obj of that.manifests
    
                  # Flush out all annotations for this canvas.
                  p = obj.getPosition()
                  s = obj.getSequence()
                  seq = obj.dataStore.data.getItem s
                  canvasKey = seq.sequence?[p]
    
                  allAnnos = obj.dataView.canvasAnnotations.items()
                  obj.dataView.canvasAnnotations.removeItems(allAnnos)
    
                  annos = obj.getAnnotationsForCanvas canvasKey
                  obj.dataStore.data.removeItems(annos)
    
                  # Flush out all search annotations, if any. 
                  obj.flushSearchResults()
    
                  # Load new search annotations into main data store.
                  obj.addManifestData queryURL, ->
    
                    # Parse new search annotations into presentation data store. 
                    Q.fcall(obj.loadCanvas, canvasKey).then () ->
                      if p == 0
                        newPage = p + 1
                      else
                        newPage = p - 1
                      setTimeout -> obj.setPosition newPage, 0  
                      setTimeout -> obj.setPosition p, 0
            else
              console.log "You must specify the URL to some search service."            
    
    
          #
          # #### #onManifest
          #
          # * url: manifest URL
          # * cb: callback to call when the manifest is loaded and ready
          #
          # This function accepts a callback function that will be called
          # when the manifest has been loaded and processed. The callback will
          # receive one argument representing the Application.SharedCanvas
          # instance associated with the manifest URL.
          #
          that.onManifest = (url, cb) ->
            if that.manifests[url]?
              that.manifests[url].ready ->
                cb that.manifests[url]
            else
              manifestCallbacks[url] ?= []
              manifestCallbacks[url].push cb
    
          #
          # #### #addPresentation
          #
          # * el: the DOM element to contain the shared canvas presentation
          #
          # The element should have the following data- attributes:
          #
          # * data-manifest: the URL of the manifest
          # * data-types: a comma-separated list of annotation types to render
          #
          # The data types can be any of the following:
          #
          # * Image: render any image annotations
          # * Text: render any text annotations
          #
          # N.B.: non-text and non-image annotations will still render. For example,
          # zones will render regardless of the types. Zones inherit the types,
          # so zones in a Text-only rendering will only render text annotations.
          #
          that.addPresentation = (el) ->
            manifestUrl = $(el).data('manifest')
            if manifestUrl?
              manifest = that.manifests[manifestUrl]
              if !manifest?
                manifest = Application.SharedCanvas.initInstance
                  url: manifestUrl
                that.manifests[manifestUrl] = manifest
                manifest.ready -> 
                  cbs = manifestCallbacks[manifestUrl] || []
                  cb(manifest) for cb in cbs
                  delete manifestCallbacks[manifestUrl]
                manifest.events.onItemsToProcessChange.addListener updateProgressTracker
                manifest.events.onItemsProcessedChange.addListener updateProgressTracker
                updateProgressTrackerVisibility()
                updateSpinnerVisibility()
                  
              manifest.run()
              types = $(el).data('types')?.split(/\s*,\s*/)
              that.onManifest manifestUrl, (manifest) ->
                manifest.addPresentation
                  types: types
                  container: $(el)
            
          #
          # Now we go through and find all of the DOM elements that should be
          # made into shared canvas presentations.
          #
          config.class ?= ".canvas"
          $(config.class).each (idx, el) -> that.addPresentation el
          that


)(jQuery, MITHgrid)

#
# The Application.SharedCanvas object ties together all of the information
# about our view of the manifest, from available sequences and annotations
# to where we are in which sequence. The application object coordinates all
# of the components and presentations concerned with a particular manifest.
#
# The app.dataViews.canvasAnnotations data view will always contain a list
# of annotations directly targeting the current canvas.
#
MITHgrid.defaults 'SGA.Reader.Application.SharedCanvas',
  dataStores:
    data:
      types:
        Sequence: {}
        Canvas: {}
      properties:
        target:
          valueType: 'item'
  dataViews:
    canvasAnnotations:
      dataStore: 'data'
      type: MITHgrid.Data.SubSet
      expressions: [ '!target' ]
    sequences:
      dataStore: 'data'
      types: [ 'Sequence' ]
  variables:
    Canvas:   { is: 'rw' }
    Sequence: { is: 'rw' }
    Position: { is: 'lrw', isa: 'numeric' }

#
# The Slider and PagerControls have the same variables so that they can be
# used interchangably.
#
MITHgrid.defaults 'SGA.Reader.Component.Slider',
  variables:
    Min:   { is: 'rw', isa: 'numeric' }
    Max:   { is: 'rw', isa: 'numeric' }
    Value: { is: 'rw', isa: 'numeric' }

MITHgrid.defaults 'SGA.Reader.Component.PagerControls',
  variables:
    Min:   { is: 'rw', isa: 'numeric' }
    Max:   { is: 'rw', isa: 'numeric' }
    Value: { is: 'rw', isa: 'numeric' }

MITHgrid.defaults 'SGA.Reader.Component.SequenceSelector',
  variables:
    Sequence: { is: 'rw' }

#
# We put the view setup here so that we don't have to remember how to
# arrange the Twitter Bootstrap HTML each time. This is looking forward
# to when this is a component outside SGA.
#
MITHgrid.defaults 'SGA.Reader.Component.ProgressBar',
  variables:
    Numerator:   { is: 'rw', default: 0, isa: 'numeric' }
    Denominator: { is: 'rw', default: 1, isa: 'numeric' }
  viewSetup: """
    <div class="progress progress-striped active">
      <div class="bar" style="width: 0%;"></div>
    </div>
  """

MITHgrid.defaults 'SGA.Reader.Component.Spinner',
  viewSetup: """
    <img src="images/spinner.gif"/>
  """

#
# We use the Canvas presentation as the root surface for displaying the
# annotations. Thus, we keep track of which canvas we're looking at.
# The Scale variable will be used to manage zooming.
#
# TODO: Have variables for panning across the canvas.
#
MITHgrid.defaults 'SGA.Reader.Presentation.Canvas',
  variables:
    Canvas: { is: 'rw' }
    Scale:  { is: 'rw', isa: 'numeric' }

#
# The ItemsToProcess and ItemsProcessed are analagous to the
# Numerator and Denominator of the ProgressBar component.
#
MITHgrid.defaults 'SGA.Reader.Data.Manifest',
  variables:
    ItemsToProcess: { is: 'rw', default: 0, isa: 'numeric' }
    ItemsProcessed: { is: 'rw', default: 0, isa: 'numeric' }

MITHgrid.defaults 'SGA.Reader.Component.ImageControls',
  variables:
    Active: { is: 'rw', default: false }
    Zoom: { is: 'rw', default: 0, isa: 'numeric' }
    MaxZoom: { is: 'rw', default: 0, isa: 'numeric' }
    MinZoom: { is: 'rw', default: 0, isa: 'numeric' }
    ImgPosition : {is: 'rw', default: {} }

MITHgrid.defaults 'SGA.Reader.Component.SearchBox',
  variables:
    Query: { is: 'rw', default: false }
    ServiceURL: { is: 'rw', default: false }