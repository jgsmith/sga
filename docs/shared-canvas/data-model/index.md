---
layout: docs
title: Shared Canvas Data Model
---
# Shared Canvas Data Model

* auto-gen TOC:
{:toc}

## General Principles / Guidelines

### Canvas Names

Canvas names can be generated automatically based on the same information in
the TEI that indicates which facsimile image is associated with a page.
Eventually, if we follow LoD practices, we will want the canvas names to be
URLs that return metadata about the canvas when dereferenced.

### Basic Approach for the TEI to Shared Canvas Process

As much as possible, we will produce the primary canvas sequence, ranges, and
canvas metadata from information in the TEI files. While the XSLT used might
produce a single file, we will be able to publish separate resources for the
sequences, ranges, and canvases. We will try to minimize the number of files
the Shared Canvas viewer tries to fetch when showing one of the
curated/published manifests. The other files are available as part of the LoD
way of publishing resources so that others outside the SGA project can remix
pieces as they want.

We will produce text annotations at the same time and will provide the set of
text annotations separately as we plan to do for sequences, ranges, etc.
Likely resources will be sets of text annotations on a per-page basis,
notebook (i.e., range) basis, and a full set of annotations for all of the
canvases in the notebooks.

We assume for now that all image annotations will map the full scan of the
page onto the entire canvas. We do not anticipate targeting a selected piece
of the canvas or the image.

### Text Annotation Relationship to Canvas

We plan on annotating each canvas with a set of zones: a left marginalia zone
and a main content zone. Because of the way Shared Canvas works, we will have
two zones for each canvas, not two zones mapped to all canvases.

For now, the primary text of the Frankenstein manuscript will be mapped to the
canvas as a single annotation. The target of the annotation should be the main
content zone. The body of the annotation should be a text range from the
original TEI. The viewer will need to pay attention to line breaks and
indentation, but will not render deletions or other aspects that could be
considered annotations of the underlying base text.

We will reproduce the deletions and other changes as annotations of the base
text.

We are putting off a number of questions until we have some data to test:

* How do we orient marginalia relative to the main body text?
* How do we order marginalia annotations in the RDF?
* Do we need more granular annotations of the base text?

## Example Annotations

The examples are shown in a textual format. As time allows, we may include
some graphical representations.

The "\_:..." references can be blank nodes or nodes with a well-defined,
dereferenceable URL. The "<...>" references should be dereferenceable URLs
that provide the RDF describing the associated resource.

### Manifest

Standard: [http://www.shared-canvas.org/datamodel/spec/#Manifest](http://www.shared-canvas.org/datamodel/spec/#Manifest)

When parsing a Shared Canvas manifest, the viewer begins with the manifest
resource URL and follows the properties to aggregations. The resources
aggregated by the manifest are themselves typically aggregations of the
resources we’re interested in: canvases, annotations, images.

    <manifest1> a sc:Manifest, ore:Aggregation ;
      dc:* ...;
      ore:aggregates _:sequence1, _:range1, _:range2, _:range3,
                     _:zoneAnnotations1, _:textAnnotations1,
                     _:imageAnnotations1 .

Here, the sequence is the normal ordering of canvases. The ranges represent
the subsets of canvases contained in each of the notebooks. The zone
annotations lists each of the annotations mapping the zones to the canvases.
The text annotations are mapping the base text onto the zones. The image
annotations are mapping the images onto the canvases.

As shared canvas evolves, it’s moving in a direction that removes the media
aspect of the annotation from the decision process as to which list the
annotation appears in. So we will eventually get to the point where the image
annotations aren’t in a list of image annotations because they are images, but
because the annotation list happens to revolve around a particular semantic
relating the images to the canvas: original light, 1990 scans, 2010 scans,
etc., providing options for someone assembling an edition.

The dc:* properties are where we can insert arbitrary Dublin Core properties
that describe the manifest resource (e.g., who assembled the manifest--who is
asserting that these resources should be brought together to construct a
scholarly edition?).

### Canvas

Standard: [http://www.shared-canvas.org/datamodel/spec/#Canvas](http://www.shared-canvas.org/datamodel/spec/#Canvas)

Canvases aren't annotations, so they are simply a bag of information about the
surface we’re annotating. The following is a sample RDF graph for a canvas
resource.

    _:canvas1 a sc:Canvas ;
      exif:width "..." ;
      exif:height "..." ;
      rdfs:label "..." .

The canvas resource can have pointers to any lists of annotations it knows
about that result in content rendered on the canvas, but these are not
necessary. This viewer doesn't use these links at the moment.

The recommendation in the spec is that multiple labels should be translations.
The viewer should then select the appropriate one. This viewer does not yet
support multiple labels.

### Canvas Sequence

Standard: [http://www.shared-canvas.org/datamodel/spec/#Sequence](http://www.shared-canvas.org/datamodel/spec/#Sequence)

A canvas sequence is an ordered list of canvases. A manifest can have multiple
sequences if you want several different orderings to be available in the
viewer.

    _:sequence1 a sc:Sequence, ore:Aggregation, rdf:List ;
      rdfs:label "..." ;
      ore:aggregates _:canvas1, _:canvas2, _:canvas3 ;
      rdf:first _:canvas1 ;
      rdf:rest ( _:canvas2, _:canvas3 ) .

In this example, we have three canvases in the sequence. We use blank nodes to
manage the linked list. The last node in the list has &lt;rdf:null> as the
pointer to the rest of the list.

### Canvas Range

Standard: [http://www.shared-canvas.org/datamodel/spec/#Range](http://www.shared-canvas.org/datamodel/spec/#Range)

A range is a subset of a sequence. It has almost the same structure as a
sequence, but only lists the canvases in the range. Ranges need not be
contiguous. They can contain parts of a canvas.

    _:range1 a sc:Range, ore:Aggregation, rdf:List ;
      dcterms:isPartOf _:sequence1 ;
      ore:aggregates _:canvasPart1, _:canvas2, _:canvas3 ;
      rdf:first _:canvasPart1 ;
      rdf:rest ( _:canvas2, _:canvas3 ) .

    _:canvasPart1 a oa:SpecificResource ;
      oa:hasSource _:canvas1 ;
      oa:hasSelector _:selector1 .

    _:selector1 a oa:FragmentSelector ;
      rdf:value "xywh=400,0,200,800" .

In this example, we have a range that covers part of the first canvas and all
of the second and third canvas.

An open question is how to use ranges to specify a reading order for the text.
We might be able to do this using the text annotation capabilities outlined
below.

### Image Annotation

Standard: [http://www.shared-canvas.org/datamodel/spec/#BasicAnnotation](http://www.shared-canvas.org/datamodel/spec/#BasicAnnotation)

Image annotations are just annotations that map an image onto a zone or
canvas. For SGA, we're planning on mapping the full image onto the full
canvas, so that's what the example here does.

    _:imageAnnotation1 a sc:ContentAnnotation, oa:Annotation ;
      oa:hasBody <imgUrl1> ;
      oa:hasTarget _:canvas1 .

    <imgUrl1> a dctypes:Image ;
      dc:format "image/jpeg" .

### Zone

Standard: [http://www.shared-canvas.org/datamodel/spec/#Zone](http://www.shared-canvas.org/datamodel/spec/#Zone)

A zone is an area of a canvas that can be the target of annotations, including
other zones. A zone has many of the same properties as a canvas since it plays
the role of one for annotations targeting them.

    _:zone1 a sc:Zone ;
      exif:height "..." ;
      exif:width "..." ;
      rdfs:label "..." ;
      sc:naturalAngle "..." ;

The easiest way to manage the height and width of a zone is to make it the
same as the area targeted on the canvas by the annotation mapping the zone
onto the canvas.

The natural angle is measured in degrees. If it's zero (i.e., the same
orientation as the underlying canvas or zone onto which this zone will be
mapped), then it can be left out.

N.B.: the natural angle is the angle by which the zone must be rotated to make
the content easier to read, not the angle by which it must be rotated to match
the orientation in the image. We read this to mean that if the text is at a 45
degree rotation from the usual with the text running from upper left to lower
right instead of straight across the paper from left to right, then the
natural angle is "-45" since we need to rotate it counter clockwise by 45
degrees to make it easier to read.

### Zone Annotation

Standard: [http://www.shared-canvas.org/datamodel/spec/#Zone](http://www.shared-canvas.org/datamodel/spec/#Zone)

Zone annotations map a zone to a canvas. It is here that we specify which part
of the canvas a zone applies to, such as offsets from the top/left (the
oa:FragmentSelector piece below).

    _:zoneAnnotation1 a sc:ContentAnnotation, oa:Annotation ;
      oa:hasBody _:zone1 ;
      oa:hasTarget _:spTarget1 ;

    _:spTarget1 a oa:SpecificResource ;
      oa:hasSource _:canvas1 ;
      oa:hasSelector _:selector1 .

    _:selector1 a oa:FragmentSelector ;
      rdf:value "xywh=200,0,300,200" .

### Text Annotation

In general, text annotations in shared canvas follow the conventions of the
Open Annotation specification with the addition of a subclass denoting that
the annotation is part of the facsimile and not part of the scholarly
commentary about the facsimile.

The following example is how we can associate unstructured text with a canvas
or zone. We can use highlight annotations to add structure to the text
annotated onto the canvas or zone.

Note that the strings “oax:TextOffsetSelector”, “oax:begin”, and “oax:end” are
subject to change as the W3C community group updates the standards
documentation. The structure shouldn’t change even if the strings used to
denote the structure do change.

According to the specification:

"The text should be normalized to a readable string before counting
characters. HTML/XML tags should be removed, character entities should be
reduced to the character that they encode, redundant whitespace should be
normalized, and so forth. This allows the Selector to be used with different
formats and still have the same semantics and utility."

We are not sure what the "and so forth" should entail, but as long as all of
the software pieces are in agreement and the relevant decisions are
documented, we should be okay. For now, we are not expanding things back into
character entities. We are relying on the DOM API to manage special
characters.

    _:textAnnotation1 a sc:ContentAnnotation, oa:Annotation ;
      oa:hasBody _:text1 ;
      oa:hasTarget _:spTarget1 .
  
    _:text1 a oa:SpecificResource ;
      oa:hasSource <teiFile> ;
      oa:hasSelector _:selector1 .

    _:selector1 a oax:TextOffsetSelector ;
      oax:begin "..." ;
      oax:end   "..." .

_:spTarget1 can be a canvas or a zone, depending on what we’re associating the
text with. &lt;teiFile> should be the URL of the TEI file that we can fetch to
supply the content we draw on the screen.

We can constrain the target of the text annotation instead of using an
intermediate zone if we don't want to aggregate annotations for an area of the
canvas:

    _:spTarget1 a oa:SpecificResource ;
      oa:hasSource _:canvas1 ;
      oa:hasSelector _:selector1 .

    _:selector1 a oa:FragmentSelector ;
      rdf:value "xywh=200,0,300,200" .

### Text Structuring Annotation

For Shelley-Godwin, we can use bodiless annotations to note where text should
be structured a particular way. For these, we can develop a simple template
that should handle most of the features we need. We can swap out the
SGA-specific class that we use (for now) for the different types of structure
we need to annotate. Text should be normalized for these annotations in the
same way it is normalized for the preceding text annotations.

The "sga" XML namespace prefix is mapped to "http://www.shelleygodwinarchive.org/ns/1#" for now.

    _:structureAnnotation1 a oa:Annotation
      oa:hasMotivation oa:Highlighting, sga:XXXAnnotation ;
      oa:hasTarget _:textTarget1 .

    _:textTarget1 a oa:SpecificResource ;
      oa:hasSource <teiFile> ;
      oa:hasSelector _:selector1 .

    _:selector1 a oax:TextOffsetSelector ;
      oax:begin "..." ;
      oax:end   "..." .

If we need additional information about the annotation, for example
information about which hand was used in a particular section, then we can add
a structured body to the annotation. For now, we’ll not worry about that.

The "&lt;teiFile>" should be the URL of the TEI file from which we are getting
the text that we are targeting. This should be the same URL as the TEI file we
used in the body of the content annotations. We use this to tie these
annotations to the unstructured text content annotations.

For now, the OA specification has style information attached to the target
([http://www.openannotation.org/spec/core/#Style](http://www.openannotation.org/spec/core/#Style)).
If we want to add some CSS styles to a highlight annotation, we would modify
the target as follows using content in RDF:

    _:structureAnnotation1 a oa:Annotation;
      oa:hasMotivation oa:Highlighting, sga:XXXAnnotation ;
      oa:styledBy _:cssStyle1 ;
      oa:hasTarget _:textTarget1 .

    _:cssStyle1 a oa:CssStyle, cnt:ContentAsText ;
      cnt:chars ".super { vertical-align: super } .sub { vertical-align: sub }" ;
      dc:format "text/css" .

    _:textTarget1 a oa:SpecificResource ;
      oa:hasSource <teiFile> ;
      oa:styleClass "super" ;
      oa:hasSelector _:selector1 .

    _:selector1 a oax:TextOffsetSelector ;
      oax:begin "..." ;
      oax:end   "..." .

We can replace "sga:XXXAnnotation" with one of the following classes:

* sga:LineAnnotation
* sga:DeletionAnnotation
* sga:AdditionAnnotation

### Example Normalization of TEI for Text Annotations

The original TEI file:

    <?xml version="1.0" encoding="ISO-8859-1"?><?xml-model href="../../derivatives/shelley-godwin-page.rnc"
               type="application/relax-ng-compact-syntax"?><?xml-stylesheet type="text/xsl"
               href="../../xsl/page-proof.xsl"
           ?>
    <surface xmlns="http://www.tei-c.org/ns/1.0" xmlns:sga="http://sga.mith.org/ns/1.0"
      xml:id="ox-ms_abinger_c56-0001" ulx="0" uly="0" lrx="5078" lry="7304" partOf="#ox-ms_abinger_c56">
      <graphic url="../../images/ox/ox-ms_abinger_c56-0001.tif"/>
      <zone type="library">
        <line><del rend="strikethrough">A12</del></line>
        <line>A 11</line>
        <line><unclear unit="chars" extent="1"/> Autograph</line>
        <line>__________</line>
        <line>Part of the MS of</line>
        <line>Frankenstein</line>
        <line> __________</line>
        <line>pp 64-172 (of vol I.?)</line>
        <line>ch. 6-17</line>
        <line>vol. II. pp 1-150</line>
        <line>ch I-XIV</line>
        <line>Corrections in another</line>
        <line>hand</line>
        <line>Dep. c. 477/1</line>
      </zone>
    </surface>

Normalized, placed into rows of ten characters bracketed by '[' and ']'. We've
collapsed tags and space into a single space except where a space seemed
significant within a tag. This might not be accurate or a reasonable algorithm
since we can’t know for sure what is a significant space within an element.

    000-009 [   A12 A 1]
    010-019 [1  Autogra]
    020-029 [ph _______]
    030-039 [___ Part o]
    040-049 [f the MS o]
    050-059 [f Frankens]
    060-069 [tein  ____]
    070-079 [______ pp ]
    080-089 [64-172 (of]
    090-099 [ vol I.?) ]
    100-109 [ch. 6-17 v]
    110-119 [ol. II. pp]
    120-129 [ 1-150 ch ]
    130-139 [I-XIV Corr]
    140-149 [ections in]
    150-159 [ another h]
    160-169 [and Dep. c]
    170-178 [. 477/1  ]
