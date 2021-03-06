require! { querystring, d3, 'webtorrent': WebTorrent, dropzone: Dropzone, uuid, pug, speedometer }

const NODE_RADIUS = 64px

width  = window.inner-width
height = window.inner-height

window.add-event-listener \resize onresize = !->
  width  := window.inner-width
  height := window.inner-height
  svg
    .attr \width  width
    .attr \height height
  simulation.force \center d3.force-center width / 2, height / 2
  simulation.restart!

nodes = [{}]
links = []
chunks = []

root = nodes[0]
  ..x = 0.5 * width
  ..y = 0.5 * height
  ..radius = 100px
  ..progress-angle = 0

svg = d3.select \body
  .style \margin  0
  .style \padding 0
  .style \width   \100%
  .style \height  \100%
  .style \overflow \hidden
  .append \svg:svg
  .style \background-color \#030c22

load-flag = (ip) !->
  svg.append \defs
    .append \pattern
      ..
        .attr \id '' + ip
        .attr \width  64
        .attr \height 64
      ..append \svg:rect
        .attr \width  2.5 * NODE_RADIUS
        .attr \height 2.5 * NODE_RADIUS
        .style \fill \#20293f
      ..append \svg:image
        .attr \width  2 * NODE_RADIUS
        .attr \height 2 * NODE_RADIUS
        .attr \xlink:href "flag?ip=#ip"


progress-arc = d3.arc!
  .inner-radius 105px
  .outer-radius 120px
  .start-angle  0rad

chunk-arc = d3.arc!
  .inner-radius 100px
  .outer-radius 105px

peer-chunk-arc = d3.arc!
  .inner-radius 64px
  .outer-radius 67px

svg.select-all \.node
  .data nodes
    .enter!.append \svg:g
      ..
        .attr \id \root-node
        .attr \class \node
      ..append \svg:g
        ..
          .attr \transform 'scale(0)'
            .transition!
              .duration 1000
              .ease d3.easeElastic
              .attr \transform 'scale(1)'
        ..append \svg:path
          .attr \fill \green
          .attr \d progress-arc end-angle: 0
        ..append \svg:circle
          .attr \r -> it.radius
          .style \fill \#e0d498
        ..append \foreignObject
          .attr \x -100px
          .attr \y -100px
          .attr \width  200px
          .attr \height 200px
          .append \xhtml:body
            .attr \id \root-body
            .style \height \100%


simulation = d3.force-simulation!
  .force \link   d3.force-link!.id (d) -> d.id
  .force \charge d3.force-many-body!.strength -2000
  .force \center d3.force-center width / 2, height / 2

simulation
  .nodes nodes

simulation.force \link
  .links links
  .strength 0.01

refresh = !->
  svg.select-all \.link .data links
    ..exit!
      .transition!.remove!
        .duration 500ms
        .style \stroke-width 0px
    ..enter!.insert \svg:line \.node
      .attr \class \link
      .style \stroke \#e5e7e8
      .style \stroke-width 0px
      .transition!
        .duration 100ms
        .style \stroke-width 10px

  svg.select-all \.node .data nodes, (.id)
    ..enter!.append \svg:g
      ..
        .attr \id -> \node- + it.id
        .attr \class \node
      ..append \svg:g
        ..
          .attr \transform 'scale(0)'
            .transition!
              .duration 1000
              .ease d3.easeElastic
              .attr \transform 'scale(1)'
        ..append \svg:circle
          .style \fill -> "url(##{it.ip})"
          .attr \r -> it.radius
        ..append \svg:text
          .attr \id -> "node-up-#{it.id}"
          .attr \text-anchor \middle
          .attr \dominant-baseline \central
          .attr \fill \#e5e7e8
          .attr \dy, -(NODE_RADIUS + 15)
          .style \text-shadow '0 0 0.5em #20293f'
          .text '▲  0 bytes/s'
        ..append \svg:text
          .attr \id -> "node-down-#{it.id}"
          .attr \text-anchor \middle
          .attr \dominant-baseline \central
          .attr \fill \#e5e7e8
          .attr \dy NODE_RADIUS + 15
          .style \text-shadow '0 0 0.5em #20293f'
          .text '▼  0 bytes/s'
    ..exit!
      .transition!.remove!
        .duration 1000ms
        .select \g
          .attr \transform 'scale(0)'

  simulation
    .nodes nodes

  simulation.force \link
    .links links
    .strength 0.01

  simulation.restart!

refresh-chunks = !->
  svg.select \#root-node .select-all \.chunk
    .data chunks
      ..
        .transition!
          .attr \fill -> if it then \#f5a873 else \#20293f
      ..enter!.append \svg:path
        .attr \class \chunk
        .attr \d (chunk, id) -> chunk-arc start-angle: 2 * Math.PI * id / chunks.length, end-angle: 2 * Math.PI * (id + 1) / chunks.length
        .attr \fill -> if it then \#f5a873 else \#20293f
        .attr \fill-opacity 0
          .transition!
            .attr \fill-opacity 1

refresh-peer-chunk = (peer) !->
  svg.select "\#node-#{peer.id}" .select-all \g .select-all \.chunk
    .data peer.chunks
      ..
        .transition!
          .attr \fill -> if it then \#f5a873 else \#20293f
      ..enter!.append \svg:path
        .attr \class \chunk
        .attr \d (chunk, id) -> peer-chunk-arc start-angle: 2 * Math.PI * id / chunks.length, end-angle: 2 * Math.PI * (id + 1) / chunks.length
        .attr \fill -> if it then \#f5a873 else \#20293f

add-peer = !->
  load-flag it.ip

  it
    ..x = Math.random! * 0.5 * width  + 0.25 * width
    ..y = Math.random! * 0.5 * height + 0.25 * height
    ..radius = NODE_RADIUS
    ..ip = it.ip

  nodes.push it
  links.push source: root, target: it

  refresh!
  refresh-peer-chunk it

remove-peer = !->
  return unless ~(i = nodes.index-of it)
  nodes.splice i, 1
  for link, i in links
    if link.target is it
      links.splice i, 1

  refresh!

onresize!

simulation.on \tick ->
  svg.select-all \.link
    .data links
    .attr \x1 -> it.source.x
    .attr \y1 -> it.source.y
    .attr \x2 -> it.target.x
    .attr \y2 -> it.target.y

  svg.select-all \.node
    .data nodes
    .attr \transform -> "translate(#{it.x}, #{it.y})"

hash = window.location.pathname.substr 1

client = new WebTorrent!
  ..on \warning console.warn
  ..on \error   console.error

bytes-to-human = do ->
  units = <[ bytes kB MB GB TB PB ]>
  (bytes) ->
    return '0 bytes' unless bytes
    e = Math.floor (Math.log bytes) / Math.log 1024
    ((bytes / Math.pow 1024, e).to-fixed 2)  + ' ' + units[e]

tween-progress = (transition, progress) !->
  transition.attr-tween \d (d) ->
    interpolate = d3.interpolate d.progress-angle, progress * 2 * Math.PI
    (t) ->
      d.progress-angle = interpolate t
      progress-arc end-angle: d.progress-angle

bitfield-to-array = (bitfield, length) -> for i til length then bitfield.get i

on-wire = (wire, addr)!->
  console.log \wire
  peer =
    id: uuid.v4!
    ip: addr
    download-speed: speedometer!
    upload-speed:   speedometer!
    chunks: bitfield-to-array wire.peer-pieces, chunks.length

  wire.peer = peer
  add-peer peer

  speed-updater = set-interval !->
    d3.select "\#node-down-#{peer.id}" .text '▼  ' + (bytes-to-human peer.download-speed!) + '\/s'
    d3.select "\#node-up-#{peer.id}" .text '▲  ' + (bytes-to-human peer.upload-speed!) + '\/s'
  , 1000

  wire
    #..on \choke   !-> console.log \choke
    #..on \unchoke !-> console.log \unchoke

    #..on \interested   !-> console.log \interested
    #..on \uninterested !-> console.log \uninterested

    ..on \have (id) !->
      return if peer.chunks[id]
      @peer.chunks[id] = true
      refresh-peer-chunk @peer

    ..on \bitfield !->
      @peer.chunks = bitfield-to-array @peer-pieces, chunks.length
      refresh-peer-chunk @peer

    #..on \request  !-> console.log \request, arguments
    #..on \piece    !-> console.log \piece, arguments

    ..on \upload !->
      @peer.download-speed it
      d3.select "\#node-down-#{@peer.id}" .text '▼  ' + (bytes-to-human @peer.download-speed!) + '\/s'

    ..on \download !->
      @peer.upload-speed it
      d3.select "\#node-up-#{@peer.id}" .text '▲  ' + (bytes-to-human @peer.upload-speed!) + '\/s'

    ..once \close !->
      clear-interval speed-updater
      remove-peer @peer

on-torrent = (torrent) !->
  chunks := bitfield-to-array torrent.bitfield, torrent.pieces.length

  for wire in torrent.wires
    on-wire wire, wire.remote-address

  torrent.on \wire on-wire

  torrent.on \download !->
    svg.select \.node .select \path
      .transition!
        .call tween-progress, torrent.progress

    d3.select \#download-speed .text (bytes-to-human client.download-speed) + '\/s'

    if torrent.progress is 1
      chunks .= map -> true
      on-download-complete torrent.files[0]
      refresh-chunks!
      return

    chunks := bitfield-to-array torrent.bitfield, torrent.pieces.length
    refresh-chunks!

  torrent.on \upload   !->
    d3.select \#upload-speed   .text (bytes-to-human client.upload-speed) + '\/s'

  set-interval !->
    d3.select \#upload-speed   .text (bytes-to-human client.upload-speed) + '\/s'
    d3.select \#download-speed .text (bytes-to-human client.download-speed) + '\/s'
  , 1000

  d3.select \#preview-button .on \click ->
    alert 'Coming soon!'

  d3.select \#download-button .on \click ->
    unless blob-URL?
      alert 'Something went wrong with the download! Please refresh and try again.'
      return
    document.create-element \a
      ..download = filename
      ..href = blob-URL
      ..click!

  #torrent.files.for-each !->
  #  it.append-to \body


require! './templates/stats.pug'

unless hash.match /\b([0-9a-f]{40})\b/
  require! './templates/upload.pug'

  d3.select \#root-body .html upload!

  new Dropzone \div#upload do
    url: \#
    accept: ->
    addedfile: !->
      d3.select \#root-body .html stats!
      d3.select \#speeds .style \margin-top \32px
      d3.select \#preview .style \display \inline
      d3.select \#filename .text it.name
      d3.select \#filesize .text bytes-to-human it.size
      client.seed it, !->
        window.history.replace-state {}, 'Info Hash', "/#{it.infoHash}"
        on-torrent it

    thumbnail-width: null

    thumbnail: (file, data) !->
      d3.select \#thumbnail
        .style \background-image "url('#data')"

else
  d3.select \#root-body .html stats!

  filename = ''
  blob-URL = null

  on-download-complete = (file) !->
    d3.select \#buttons
      .style \display \inline

    filename := file.name

    file.get-blob-URL (err, url) !->
      if (err)
        alert err
        return
      blob-URL := url

  client.add hash, !->
    on-torrent it
