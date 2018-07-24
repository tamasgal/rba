
# this is the aa3d event display for antares and km3net

# object that will hold all the user-modifiable parameters (and then some)
pars = {}   
defpars = {}

# physics-domain data 
clight = 0.299792458  # m/ns 
evt = {"hits": [], "trks":[]};
det = {"doms": [{"id": 1, "dir": {"y":0, "x": 0, "z": 0}, "pos": {"y": 0, "x": 0, "z": 0} }] };

# three.js objects
scene= camera= renderer= raycaster= mouseVector= controls = null;
geometry= material= mesh= null
container= stats= gui = null
containerWidth= containerHeight= null
eventtime = 0.0;
light= null 
gui = null
effect = null
train = null

selectedHit = null
ii = null#
dus = 42
callbacks = {} 
selected = null

dbg_cam = false


evil = ( code ) -> eval ( code ) # eval's evil brother (to access scope)


#-----------------------------------------
# Simple Vector functions and math utils
#-----------------------------------------

isvec = ( obj ) -> typeof(obj) == 'object' and 'x' of obj and 'y' of obj and 'z' of obj

vadd = ( v1, v2 ) -> { x : v1.x + v2.x, y: v1.y + v2.y , z: v1.z + v2. z }
vsub = ( v1, v2 ) -> { x : v1.x - v2.x, y: v1.y - v2.y , z: v1.z - v2. z }
  
vmul = ( v1, a ) ->
  if typeof v1 == 'number' then return vmul( a, v1 )
  return { x: v1.x * a, y: v1.y * a, z : v1.z * a }

vlen = ( v1, v2 = {x:0,y:0,z:0} ) ->
  Math.sqrt( (v1.x-v2.x)*(v1.x-v2.x) + (v1.y-v2.y)*(v1.y-v2.y) + (v1.z-v2.z)*(v1.z-v2.z) )

tovec = (obj) ->
  new THREE.Vector3 obj.y, obj.z, obj.x 

clamp = ( x, min=0, max=1 ) ->
  if x <= min then return min
  if x >= max then return max
  return x    
            

getUrlPar = (name, url ) ->
    
  url ?= window.location.href
  name = name.replace(/[\[\]]/g, "\\$&")

  regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)");
  results = regex.exec(url);
  if !results then return null
  if !results[2] then return ''
  return decodeURIComponent(results[2].replace(/\+/g, " "));  


getCylinderMesh = ( startpoint, endpoint, width  , material , width2 ) ->
    
  l = vlen( endpoint, startpoint )
  width2 ?= width

  geom = new THREE.CylinderGeometry( width, width2 , l );
  geom.translate(0, l/2 ,0);
  geom.rotateX( Math.PI / 2 );
   
  mesh = new THREE.Mesh( geom , material.clone() ); 
  mesh.position.set( startpoint.y, startpoint.z, startpoint.x );
  mesh.lookAt( tovec(endpoint) );
  return mesh;         


getConeMesh = ( startpoint, endpoint, width, material ) ->
    getCylinderMesh( startpoint, endpoint, width, material, 0 )

callbacks.setBackgroundColor = -> 
	scene.background = new THREE.Color( pars.bgColor )


callbacks.screenshot = ->
    dt = renderer.domElement.toDataURL( 'image/png' );
    window.open( dt, 'screenshot')


callbacks.screenshot360 = ->
        console.log("screenshot360")
        X = new CubemapToEquirectangular( renderer, true );
        X.update( camera, scene )


callbacks.write_screenshot = (fn) ->
    
    url    = "uploadimg.php"
    params = "fn="+fn+".png&payload="+renderer.domElement.toDataURL( 'image/png' );
    console.log(params)
    
    http = new XMLHttpRequest()
    http.open("POST", url , false )
    
    #Send the proper header information along with the request
    http.send( params )
    if http.readyState == 4 && http.status == 200 then console.log(http.responseText)
    else console.log('error sending screenshot')
	

callbacks.addCamera =->
	
    camera ?= new THREE.PerspectiveCamera( 75,window.innerWidth / window.innerHeight, 0.01, 10000 );
    camera.position.x = 0
    camera.position.y = pars.camHeight
    camera.position.z = pars.camDistance
    

callbacks.addOrbitControls =->

    controls = new THREE.OrbitControls( camera ,  renderer.domElement )
    cg = det.cg or {x:0, y:0, z:0}  # det may not exist yet
    controls.center = new THREE.Vector3(cg.z, cg.y, cg.x) or new THREE.Vector3( camera.position.x, camera.position.y, 0.0  )
    controls.update()
    controls.addEventListener( 'change', render )
    return controls

getSceneObj = ( name ) ->

    while obj = scene.getObjectByName( name )
        scene.remove( obj )
   
    obj = new THREE.Object3D()
    obj.name = name
    scene.add( obj )
    return obj



isNeutrino = (track) -> Math.abs( track.type ) in [12,14,16]
isLepton   = (track) -> Math.abs( track.type ) in [11,13,15]
isMuon     = (track) -> Math.abs( track.type ) == 13

trackColor = ( track ) ->

    if track.type == 0
        return new THREE.Color( pars.trackColor )

    if isNeutrino( track )
        return new THREE.Color( pars.neuColor )

    if isMuon( track)
        return new THREE.Color( pars.muColor )

    return new THREE.Color( pars.mcTrackColor ) 


trackLength = ( track ) ->

    #if isNeutrino( track ) then return pars.neuLen

    if isMuon(track)
        if track.len? != 0 then return Math.abs(track.len)
        
        if track.E? 
            l = track.E * 5 
            if l<20 then l = 20;
            if l>4000 then l = 4000;
        return l

    if track.len > 0 then return track.len 	
    return pars.trackLen 


addDoms_mergedgeomery = ->

    return unless pars.showDoms
    doms = getSceneObj( "doms" )

    geo  = new THREE.SphereGeometry( pars.domSize,2*pars.domDetail, pars.domDetail ) 
    mat  = new THREE.MeshLambertMaterial( { color: new THREE.Color( pars.domColor )} ) 
    mesh = new THREE.Mesh( geo );
    mergedGeo = new THREE.Geometry();

    for id, dom of det.doms
        
        if dom.dir? then d = vmul( pars.domFactor,  dom.dir) 
        else d = {x:0,y:0,z:1}
        mesh.position.set( dom.pos.y + d.y, dom.pos.z + d.z, dom.pos.x + d.x);
        mesh.updateMatrix()
        mergedGeo.merge( mesh.geometry, mesh.matrix )
    
    group   = new THREE.Mesh( mergedGeo, mat );
    doms.add(group)



addDoms_shader = ->

    return unless pars.showDoms
    doms = getSceneObj( "doms" )

    geo = new THREE.InstancedBufferGeometry()

    sphere =  new THREE.SphereGeometry( pars.domSize,2*pars.domDetail, pars.domDetail )
    sphere.rotateX( Math.PI )
    geo.fromGeometry( sphere )

    ndoms = 0
    ndoms++ for id, dom of det.doms
    offsets = new THREE.InstancedBufferAttribute( new Float32Array( ndoms * 3 ), 3, 1 );
    orientations = new THREE.InstancedBufferAttribute( new Float32Array( ndoms * 3 ), 3, 1 )

    i= 0
    for id, dom of det.doms
    	
        if not dom.dir? or dom.dir.z > 0 # for antares it will be <0 
        	dom.dir =  {x:0,y:0,z:1}
        	d       =  {x:0,y:0,z:0}
        else # for antares
        	d = vmul( pars.domFactor, dom.dir) 
        
        offsets.setXYZ( i, dom.pos.y + d.y , dom.pos.z + d.z , dom.pos.x + d.x )
        orientations.setXYZ( i, dom.dir.y, dom.dir.z, dom.dir.x )
        
        #console.log( dom.pos, dom.dir )
        i+=1
    
    geo.addAttribute( 'offset', offsets ); # per mesh translation (i.e. dom-position)
    geo.addAttribute( 'orientation', orientations );
    uniforms_ = THREE.UniformsUtils.merge( [
    	THREE.UniformsLib[ "ambient" ],
    	THREE.UniformsLib[ "lights" ] ] );
    	
    material = new THREE.RawShaderMaterial
          uniforms        : uniforms_
          vertexShader    : vertexshader_glsl
          fragmentShader  : window[pars.domFragmentShader] 
          side            : THREE.DoubleSide
          lights          : true 
          transparent     : false 

    group = new THREE.Mesh( geo, material );
    group.frustumCulled = false;
    doms.add( group );
    

callbacks.addDoms = addDoms_shader  



callbacks.addFloor = ->

	floor = getSceneObj("floor")
    
	det.floor_z = det.floor_z or Math.min( dom.pos.z for id,dom of det.doms... )-100
	console.log( "addFloor" , det.floor_z);
	texture = new THREE.TextureLoader().load( 'textures/image.png' );
	texture.wrapS = THREE.RepeatWrapping;
	texture.wrapT = THREE.RepeatWrapping;
	texture.repeat.set( 100, 100 );

	geo = new THREE.PlaneGeometry(20000,20000,1,1);   
	mat = new THREE.MeshBasicMaterial( {
		color: pars.floorColor, 
		side: THREE.DoubleSide,
		opacity : pars.floorOpacity,
		transparent: false,	
		map: texture 
		} )
		
	mesh = new THREE.Mesh( geo, mat );
	mesh.rotation.x   = 0.5*Math.PI;        
	mesh.position.y   = det.floor_z;	
	floor.add( mesh );


callbacks.addStrings = ->

    return unless pars.showStrings
    return unless det.strings 
    strings = getSceneObj( "strings" )
    
    mat = new THREE.MeshLambertMaterial ( color: new THREE.Color( pars.stringColor ) )

    endpos = null
    for stringpos in det.strings

        startpos = tovec( stringpos )

        if endpos 
            mesh = getCylinderMesh( startpos, endpos , pars.stringWidth, mat );
            strings.add(mesh)
    
        endpos = startpos


timeParameter= ( hit, track ) ->
    switch pars.colScheme 
        when 'time'   then hit.t
        when 'track'  then hit.t - time_track( track, hit.pos )
        when 'shower' then hit.t - time_shower( track, hit.pos ) 



getHitColor = ( time , timerange, track ) ->

    [mint, maxt] = timerange
    aa  = ( time - mint) / ( maxt - mint );
    col = new THREE.Color()

    if pars.palette == 'hue'
        col.setHSL( aa , 1.0, 0.5 );
    if pars.palette == 'doppler'
        col.setRGB( 1-clamp( aa*aa ) , 0 , clamp( aa*2-1 ) )

    return col


addHits_manymeshes = ->
    
    hits = getSceneObj( "hits" )

    hitarray = evt[ pars.hitSet ]
    if !hitarray then return
    
    if pars.hitStyle == 'sphere' 
        geo  = new THREE.SphereGeometry( 2, 2*pars.hitDetail, pars.hitDetail )
    
    if pars.hitStyle == 'disk'  
        geo = new THREE.CylinderGeometry( 2, 2 , 0.1 , pars.hitDetail , 1 ) # z-component will be scaled later
        geo.translate(0, 0.05 ,0)
        geo.rotateX( Math.PI / 2 )
        have_direction = true

    # min/max time for collormapping
    evt.timerange = evt.timerange || [ Math.min( hit.t for hit in hitarray... ), Math.max(  hit.t for hit in hitarray... ) ]
    
    eval ('ampfun = function(hit) { return '+pars.ampFunc+';};')
    for hit in hitarray

        if pars.animate and hit.t > eventtime then continue

        col  = getHitColor( hit.t , evt.timerange )
        mat  = new THREE.MeshLambertMaterial( color: col );
        mesh = new THREE.Mesh( geo , mat );
        mesh.t = hit.t
        
        d = hit.dir || {x:0,y:0,z:0}

        a = pars.domFactor
        mesh.position.set(
            hit.pos.y + a * d.y
            hit.pos.z + a * d.z
            hit.pos.x + a * d.x )

        a *= 2
        if have_direction then mesh.lookAt( new THREE.Vector3(
            hit.pos.y + a * d.y
            hit.pos.z + a * d.z
            hit.pos.x + a * d.x ) )

        amp = ampfun( hit ) * pars.hitLength
        mesh.scale.set( amp, amp, amp) if pars.hitStyle == 'sphere'
        mesh.scale.set( 1,1,amp )  if pars.hitStyle == 'disk'
        hits.add( mesh )


callbacks.animateHits_manymeshes = ->
    
    #console.log( eventtime )
    hits = scene.getObjectByName( "hits" ).children
    
    for mesh in hits 
        mesh.visible = mesh.t > eventtime and mesh.t < (eventtime+200) 
        
    


distFromCamera = ( pos ) ->
    x = pos.y - camera.position.x
    y = pos.z - camera.position.y
    z = pos.x - camera.position.z
    r = (x*x + y*y + z*z)
    return r
    #   tovec( obj.pos).project( camera ).z
   

#----------------------------------------------------------
populateHitInstanceBuffers = ->
    window.alert("populateHitInstanceBuffers cannot be called before addHits_shader");


make_hitcol = ( hitlist ) ->

    X = {}    
    ( X[ hit.dom_id ] ?= [] ).push( hit ) for hit in hitlist
    hitcol = (v for k,v of X) 

    hitcol.doms_are_sorted = (verbose ) ->
        olddepth = 1e10 
        r = true
        for hitsondom in this
            h = hitsondom[0]
            h.depth = distFromCamera( h.pos )
            if verbose then console.log( h.depth )
            if h.depth > olddepth then r = false
            olddepth = h.depth
        return r

    hitcol.dbg = -> 
        for lst,i in this
            console.log( i, lst[0].depth )
            if i > 10 then break

    hitcol.sort_doms = ->
        this.sort( (lst1, lst2) -> lst1[0].depth < lst2[0].depth  )
    
    hitcol.sort_within_doms = ->
        for lst in this
            h.depth = distFromCamera( h.pos ) for h in lst
            lst.sort( (h1,h2) -> h1.depth < h2.depth  )    

        
    hitcol.sort_all = ->
        unless this.doms_are_sorted()
            this.sort_doms()
            this.sort_within_doms()
            populateHitInstanceBuffers()

    return hitcol



callbacks.depthSort = ->
    
    t0 = (new Date()).getTime()
    evt.sorted_hits.sort_all()  
    t1 = (new Date()).getTime()
    console.log("depthSort took", t1-t0 )


callbacks.onNewEvent = ->
        
    evt.tag = "evt"
    evt.sorted_hits    = make_hitcol( evt.hits    )
    evt.sorted_mc_hits = make_hitcol( evt.mc_hits )

    for trk in evt.mc_trks
        if isNeutrino( trk )
                # move neutrino back 10 km
                vv = vmul( 10000.0 , trk.dir )
                trk.pos = vsub( trk.pos , vv )
                trk.len = 10000
                trk.t = trk.t - trk.len / clight
                
    if scene?
        callbacks.addHits()
        callbacks.addTracks()


callbacks.onNewDetector = ->

	console.log 'onNewDetector'
	if det.name == "antares" then antares_mode()
	
	det.tag = "det"
	det.cg  = {x:0,y:0,z:0}
	det.ndoms = 0

	for id, dom of det.doms 
		det.ndoms += 1
		det.cg = vadd( det.cg, dom.pos )



addHits_shader = ->

    hits = getSceneObj( "hits" )
    hitarray = evt[ pars.hitSet ]
    if !hitarray then return

    console.log('addHits', hitarray.length );    

    evt.timerange = [ Math.min( hit.t for hit in hitarray... ), Math.max(  hit.t for hit in hitarray... ) ]

    geo = new THREE.InstancedBufferGeometry()
    disk = new THREE.CylinderGeometry( pars.hitWidth,
                                       3*pars.hitWidth , 0.1 , pars.hitDetail , 1 ) # z-component will be scaled later
    disk.translate(0, -0.05 ,0)
    disk.rotateZ( Math.PI / 2 )
    geo.fromGeometry( disk )
    
    nhits = hitarray.length

    offsets      = new THREE.InstancedBufferAttribute( new Float32Array( nhits * 3 ), 3, 1 ).setDynamic( true );
    orientations = new THREE.InstancedBufferAttribute( new Float32Array( nhits * 3 ), 3, 1 ).setDynamic( true );
    colors       = new THREE.InstancedBufferAttribute( new Float32Array( nhits * 3 ), 3, 1 ).setDynamic( true );
    amplitudes   = new THREE.InstancedBufferAttribute( new Float32Array( nhits     ), 1, 1 ).setDynamic( true );
    times        = new THREE.InstancedBufferAttribute( new Float32Array( nhits     ), 1, 1 ).setDynamic( true );
    tots         = new THREE.InstancedBufferAttribute( new Float32Array( nhits     ), 1, 1 ).setDynamic( true );
    geo.addAttribute( 'offset', offsets ); 
    geo.addAttribute( 'orientation', orientations );
    geo.addAttribute( 'color', colors );
    geo.addAttribute( 'amplitude', amplitudes ); 
    geo.addAttribute( 'time', times );
    geo.addAttribute( 'tot', tots );

    a = pars.domFactor
    
    populateHitInstanceBuffers = ->
    	
        eval ('ampfun = function(hit) { return '+pars.ampFunc+';};')
        t1 = (new Date()).getTime()
        i = 0
        for domhits in evt.sorted_hits
            for hit in domhits
        
                col  = getHitColor( hit.t , evt.timerange )        
                d    = hit.dir || {x:0,y:0,z:1}
        
                offsets.setXYZ( i, hit.pos.y + a * d.y, hit.pos.z + a * d.z, hit.pos.x + a * d.x )
                orientations.setXYZ( i, hit.dir.y, hit.dir.z, hit.dir.x ); # todo and to think-about
                colors.setXYZ(i, col.r, col.g, col.b )
                amplitudes.setX(i, ampfun(hit)* pars.hitLength );
                times.setX(i, hit.t );
                tots.setX(i, hit.tot * pars['aniTotFactor']);
                i+=1


        t2 = (new Date()).getTime()
        offsets.needsUpdate = true    
        orientations.needsUpdate = true    
        colors.needsUpdate = true          
        amplitudes.needsUpdate = true      
        times.needsUpdate = true           
        tots.needsUpdate = true                
        # console.log("polulating buffers took", t2-t1 )

    populateHitInstanceBuffers()
        
    material = new THREE.RawShaderMaterial( {
          uniforms: { "eventtime": { type: "1f", value: 0 }
          },
          vertexShader    : hit_vertexshader_glsl,
          fragmentShader  : hit_fragmentshader_glsl,
          side            : THREE.BackSide ,
          transparent     : true } );

    mesh = new THREE.Mesh( geo, material );
    mesh.frustumCulled = false;

    hits.add( mesh );
    

callbacks['addHits'] = ->

    if pars.hitStyle == 'cone' then addHits_shader()
    else addHits_manymeshes()


callbacks.addTracks = ->

   trks = getSceneObj 'trks'
   if typeof t == 'undefined' then t = 1e10
     
   trkcol = evt[pars.tracks] or []
   
   for trk in trkcol

       trklen = trackLength( trk )

       startpos = trk.pos
       endpos   = vadd( trk.pos, vmul( trk.dir, trklen ) )
       startt   = trk.t
        
       if isNeutrino( trk )
           startpos = vadd( trk.pos,  vmul( trk.dir, -trklen ) );
           endpos   = trk.pos
           startt  -= trklen / clight
        
       mat = new THREE.MeshPhongMaterial ( {
                 emissive: new THREE.Color( trackColor(trk) ),  
                 transparent: false , 
                 opacity: 0.5 } )
                                 
       mesh = getCylinderMesh( startpos, endpos, pars.trackWidth, mat )
       mesh.t0 = startt
       mesh.t1 = startt + trklen / clight; 
       
       console.log("track", startpos, endpos , trklen )
       trks.add (mesh)


callbacks.animateTracks = ( t ) ->
        
    trks = scene.getObjectByName( 'trks' )
 
    for mesh in trks.children
        f = clamp ( (t - mesh.t0 ) / ( mesh.t1 - mesh.t0 ) )
        mesh.scale.set( 1,1,f )
        #console.log('anim trka', mesh.t0, mesh.t1, t , f)  


callbacks.addEvt = ->
    callbacks.addHits()
    callbacks.addTracks()


callbacks.addDet = ->
    callbacks.addFloor() 
    callbacks.addStrings()
    callbacks.addDoms()

handlefile= ( e ) -> console.log( "filetje:", e.target.files )

callbacks.loadLocalFile = ->

    element = document.createElement('div')
    element.innerHTML = '<input type="file">'
    fileInput = element.firstChild
    fileInput.addEventListener('change', handlefile )
    fileInput.click()
	
        
	
# At this point, all callbacks are defined and we
# can initialze the dat.gui. Note that the callbacks
# use the parameters defined in pars by buildmenu.
	
gui = window.buildmenu( pars , callbacks )	


callbacks.vr_demo = (tnow) ->	
	window[pars.demo]?( tnow )
	
vr_demo1 = (tnow) ->
	
	train.position.y = 500 + 400 * Math.sin( tnow/10000.0 )
	

addVRButton = ->
	
	WEBVR.getVRDisplay( (display) -> 
	
		if not display?
			console.log("no vr display found")
			return 
			
		renderer.vr.setDevice( display )
		gui.add( { "VR_mode" : -> 
			console.log("toggling vr mode!");
			
			controls = new THREE.VRControls( camera );
			effect = new THREE.VREffect( renderer  );
			
			
			if display.isPresenting then display.exitPresent() # crashes
			else : display.requestPresent( [ { source: renderer.domElement } ] );
			
			#callbacks.vr_demo = vr_demo1
			
			} , "VR_mode" ) 
		

	)



init = ->
    
        t1 = (new Date()).getTime();
        scene = new THREE.Scene()  
        console.log("bg col = ", pars.bgColor) 

        
        renderer = new THREE.WebGLRenderer
                preserveDrawingBuffer   : true
                antialias : true 
        
        renderer.setPixelRatio( window.devicePixelRatio );
        renderer.setSize( window.innerWidth, window.innerHeight )
        container.appendChild( renderer.domElement ) 


        # --stats box-
        stats = new Stats()
        container.appendChild( stats.dom );
        
        window.addEventListener( 'resize', onWindowResize, false );
        
        
        light = new THREE.PointLight(0xffffff)
        light.position.set(500,1000,0)
        scene.add(light)
        
        al = new THREE.AmbientLight(0x444444);
        scene.add(al);
        
        pars[attrname] = defpars[attrname] for attrname of defpars
        
        console.log('call addcontrols', renderer) 
        callbacks.setBackgroundColor()
        callbacks.addCamera() 
        callbacks.addStrings()
        callbacks.addDoms()
        callbacks.addTracks()
        callbacks.addHits()
        callbacks.addFloor()
        callbacks.addOrbitControls()
        

        # If we are not in VR mode, then the 'train' does not do anything
        # otherwise it defines a sort of platform for the 'player' to stand on
        
        train = new THREE.Object3D()
        train.position.set( 0,0,0)
        scene.add( train );
        train.add( camera )
        
        
        addVRButton();
   
        raycaster   = new THREE.Raycaster();
        mouseVector = new THREE.Vector2();
        showSelectionInfo( evt );
        
        t2 = (new Date()).getTime();
        console.log("init took (ms) : ", t2-t1 );

        websock = new WebSocket("ws://www.cherenkov.nl:8181", "protocolOne");
        
        websock.onmessage = (event) ->

          console.oldlog("get wesocket message:", event.data);
          s = eval( event.data )
          
          console.log( JSON.stringify(s) )
          
        websock.onopen = () -> # replace console.log
        
          console.oldlog = console.log  
          console.log = () ->
            a = Array.prototype.slice.call(arguments)
            console.oldlog( arguments )
            websock.send( a.toString() )
          
          
          


showSelectionInfo = ->
	
	selected ?= evt
	
	infodiv = document.getElementById("info")

	if not infodiv 
		
		infodiv = document.createElement 'div'
		infodiv.id = 'info'
		infodiv.big = false
		
		infodiv.addEventListener "click", ->
			console.log 'click'
			infodiv.big = !infodiv.big
			showSelectionInfo()
		
		document.body.appendChild infodiv 
		
	
	M = {'trk':'Track', 'hit':'Hit', 'evt':'Event'}
	html = """ <h3> #{M[selected.tag]} #{selected.id} </h3> <table style="width:100%"><tr> """
	
	if infodiv.big # list all attributes of 'selected' object
    		
    	for key, val of selected
    			
    		if Array.isArray(val) then val = val.length.toString() + "entries"
    		if isvec( val )       then val = val.x.toFixed(3) +', ' + val.y.toFixed(3) + ', ' + val.z.toFixed(3);
    		
    		html += '<tr><td> '+key+' </td><td> '+val+'</td></tr>'
    			
    html += '</table>'
    infodiv.innerHTML = html
   







`



function onMouseMove( e ) 
{
	console.log ("mousemove")

    mouseVector.x = 2 * (e.clientX / window.innerWidth ) - 1;
    mouseVector.y = 1 - 2 * ( e.clientY / window.innerHeight );
    
    raycaster.setFromCamera( mouseVector, camera );
    
    var searchObjects = ["hits","trks"]; 
    
    flag = false;

        if ( selectedHit) 
        {
                selectedHit.material.emissive.setHex( selectedHit.oldHex); 
        }


    for ( var ii = 0; ii<searchObjects.length; ii++ )
    {
        var collection = scene.getObjectByName( searchObjects[ii] );
        
        console.log( collection );
        
        var intersects = raycaster.intersectObjects( collection.children );
        
        console.log("intersects", intersects );

               
        if ( intersects.length > 0 ) 
        {
        var sel = intersects[ 0 ].object;
        
        if ( sel.hasOwnProperty("aaobj") ) 
        {
            selectedHit = sel;
            
            sel.oldHex = sel.material.emissive.getHex();
            sel.material.emissive.setHex( 0xff0000 );
    
            sel.aaobj.tag = searchObjects[ii].substring(0,3);
        
            showSelectionInfo( sel.aaobj );
            flag = true;
        }
        }
    }
    
    evt.tag = "evt";
    if (!flag)  showSelectionInfo( evt );
}


function onWindowResize() 
{
    //windowHalfX = window.innerWidth / 2;
    //windowHalfY = window.innerHeight / 2;   
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    //
    
    if (effect)
    {
    	setSize( window.innerWidth, window.innerHeight );
    }
    else
    {
    	renderer.setSize( window.innerWidth, window.innerHeight );
    	render();
    
    }
    
    //render();
    
    
    
}


function animate() 
{
	
    // schedule next one

    if (effect) 
    { 
      effect.requestAnimationFrame( animate ); 
    }
    else
    {
      requestAnimationFrame( animate );
    }
    

    var tnow = (new Date()).getTime();

    if (!pars.animate)
        {
         scene.getObjectByName( 'hits' ).children[0].material.uniforms.eventtime.value = eventtime;
         eventtime = 2e100;
        }
    else
        { 
        // --- animation time ---    
        var slowdown = pars.ns_per_s /1000.0 ;         
        var tx = tnow * slowdown;

        var t1 = evt.timerange[0] - pars.introTime;
        var t2 = evt.timerange[1] + 255.0 * pars.aniTotFactor + pars.outroTime
                 
        eventtime = ( tx % (t2-t1)) + t1 ;
	callbacks.animateTracks( eventtime );

        

    if (pars.hitStyle == 'cone')
        {
         scene.getObjectByName( 'hits' ).children[0].material.uniforms.eventtime.value = eventtime;
        }
    else
        {
         if (pars.animate) {callbacks.animateHits_manymeshes()};
        }

	}



    if ( typeof animate.tthen == 'undefined' ) animate.tthen = tnow;
    
    var dt = animate.tthen-tnow;
    animate.tthen = tnow;

	callbacks.vr_demo( tnow )

	 if ( pars.rotate ) 
     {
        var ax = new THREE.Vector3( 0, 1, 0 );  
        camera.position.applyAxisAngle( ax , 0.00001* pars.rotationSpeed * dt );
     }
    
    controls.update();
    stats.update();     
    render();
}

`

render = ->
	
	#console.log(render)
	
	render.n ?= 0
	render.n+=1

	THREE.VRController.update()

	#if pars.depthSortEvery > 0 and render.n % pars.depthSortEvery == 0 then callbacks.depthSort()
	
	if effect 
		effect.render( scene, camera )
	else
		renderer.render( scene, camera )


newwindow = -> window.new_window_ref = window.open( window.location )


container = document.createElement( 'container' );
container.id = "container";
document.body.appendChild( container );

initdiv = document.createElement( 'div' );
initdiv.id = 'init';
initdiv.innerHTML = '<br>aa3d starting up.</br>';
document.body.appendChild( initdiv );


unzip = ( buf ) ->
    
    words = new Uint8Array( buf )
    U = pako.ungzip(words)
    console.log(U)

    result = "";
    for i in [0..U.length-1]
        result+= String.fromCharCode(U[i]) ;

    return result
    


# old browsers dont have str.endsWidth
str_endsWith = (s, suffix) ->
    s.indexOf(suffix, s.length - suffix.length) != -1;


antares_mode = ->
	console.log("antares mode")
	pars.set( "domFragmentShader", "fragmentshader_antares_glsl")
	pars.set( "camHeight" ,   200     )
	pars.set( "camDistance",  250     )
	pars.set( "domSize",      2.0     )
	pars.set( "domFactor",    3       )
	pars.set( "hitStyle",    "sphere" )
	pars.set( "ampFunc",     "Math.sqrt(hit.a)" )
	pars.set( "palette",     "hue"    )
	pars.set( "hitLength",   1.5      )
	pars.set( "depthSortEvery", 0     )
	

loadFile = ( url , asynch = true , when_done  ) ->

	console.log( url, when_done, asynch )
	
	gz = str_endsWith( url, ".gz" )
	xmlhttp = new XMLHttpRequest()
	if gz then xmlhttp.responseType = 'arraybuffer';
	
	process = ( req ) ->
		if gz
            s = unzip( xmlhttp.response )
            eval( s )
        else
            eval( xmlhttp.responseText )
      
       	when_done?()
	
	
	if asynch
		xmlhttp.onprogress = (ev) -> console.log( 'getting file:'+url+' __ '+ ev.loaded/1e6 +' MB')
	
		xmlhttp.onreadystatechange = () ->
        	return unless xmlhttp.readyState == 4
        	return unless xmlhttp.status     == 200
        	console.log("done");
        	process( xmlhttp )

	xmlhttp.open("GET", url , asynch );
	xmlhttp.send();

	if not asynch then process( xmlhttp )
	
	
many_screenshots = ( i=0 ) ->
	
	s = """
diffuse2017/detevt_28722_45202_426
diffuse2017/detevt_35473_7183_1050
diffuse2017/detevt_38472_61820_16446
diffuse2017/detevt_38518_41252_24091
diffuse2017/detevt_38519_42310_26116
diffuse2017/detevt_39324_118871_32515
diffuse2017/detevt_45265_79259_997305
diffuse2017/detevt_45835_34256_1041663
diffuse2017/detevt_46852_51708_917709
diffuse2017/detevt_47833_1124_537259
diffuse2017/detevt_49425_32175_104853
diffuse2017/detevt_49821_56923_25516
diffuse2017/detevt_49853_25438_1385
diffuse2017/detevt_53037_101247_36731
diffuse2017/detevt_53060_41698_354601
diffuse2017/detevt_54260_1639_2925759
diffuse2017/detevt_57495_15712_326824
diffuse2017/detevt_60896_68105_494258
diffuse2017/detevt_60907_60252_572415
diffuse2017/detevt_61023_10375_2179659
diffuse2017/detevt_62657_88204_22071
diffuse2017/detevt_62834_30474_384475
diffuse2017/detevt_65811_20990_137527
diffuse2017/detevt_68473_32777_22562
diffuse2017/detevt_68883_33383_1459227
diffuse2017/detevt_70787_9986_323373
diffuse2017/detevt_71534_74641_364543
diffuse2017/detevt_74307_193564_6908522
diffuse2017/detevt_77640_77424_3612
diffuse2017/detevt_80885_49449_12484201
diffuse2017/detevt_81667_163768_2732223
diffuse2017/detevt_82539_9289_2425758
diffuse2017/detevt_82676_118860_167410
""".split("\n")
    
	for fn in s
		if not fn then continue
		
		scfile = fn.split("/").pop()
		loadFile( fn , false,  -> 
					callbacks.onNewEvent()   
					#init()
					callbacks.onNewDetector()
					render() 
					callbacks.write_screenshot(scfile) )




if window.opener then console.log("we have an opener", window.opener );

`
window.addEventListener( 'vr controller connected', function( event ){


    console.log("VR CONTROLLER!!!!!!!!!!!!!!!!!!!!!!!!!");
    
	//  Here it is, your VR controller instance.
	//  It’s really a THREE.Object3D so you can just add it to your scene:

	controller = event.detail
	train.add( controller )


	//  HEY HEY HEY! This is important. You need to make sure you do this.
	//  For standing experiences (not seated) we need to set the standingMatrix
	//  otherwise you’ll wonder why your controller appears on the floor
	//  instead of in your hands! And for seated experiences this will have no
	//  effect, so safe to do either way:

	controller.standingMatrix = renderer.vr.getStandingMatrix()


	//  And for 3DOF (seated) controllers you need to set the controller.head
	//  to reference your camera. That way we can make an educated guess where
	//  your hand ought to appear based on the camera’s rotation.

	controller.head = window.camera


	//  Right now your controller has no visual.
	//  It’s just an empty THREE.Object3D.
	//  Let’s fix that!

	var
	meshColorOff = 0xFF4040,
	meshColorOn  = 0xFFFF00,
	controllerMaterial = new THREE.MeshStandardMaterial({

		color: meshColorOff,
		shading: THREE.FlatShading
	}),
	controllerMesh = new THREE.Mesh(

		new THREE.CylinderGeometry( 0.005, 0.05, 0.1, 6 ),
		controllerMaterial
	),
	handleMesh = new THREE.Mesh(

		new THREE.BoxGeometry( 0.03, 0.1, 0.03 ),
		controllerMaterial
	)

    //controllerMesh.scale.set(100,100,100);
	controllerMesh.rotation.x = -Math.PI / 2;
	handleMesh.position.y = -0.05;
	controllerMesh.add( handleMesh );
	controller.userData.mesh = controllerMesh;//  So we can change the color later.
	controller.add( controllerMesh );


	//  Allow this controller to interact with DAT GUI.

	//var guiInputHelper = dat.GUIVR.addInputObject( controller )
	//scene.add( guiInputHelper )


	//  Button events. How easy is this?!
	//  We’ll just use the “primary” button -- whatever that might be ;)
	//  Check out the THREE.VRController.supported{} object to see
	//  all the named buttons we’ve already mapped for you!

	controller.addEventListener( 'primary press began', function( event ){
        train.position.add( controller.rotation );
		event.target.userData.mesh.material.color.setHex( meshColorOn )
		//guiInputHelper.pressed( true )
	})
	controller.addEventListener( 'primary press ended', function( event ){

		event.target.userData.mesh.material.color.setHex( meshColorOff )
		//guiInputHelper.pressed( false )
	})


	//  Daddy, what happens when we die?

	controller.addEventListener( 'disconnected', function( event ){

		controller.parent.remove( controller )
	})
})
`



url = getUrlPar('f');

if url == "none" 
    init();
    render();
    animate();

if !url then  url="detevt2_km3.js" #some test file

initdiv.innerHTML = '<br>getting file:'+url+'</br>'
console.log( 'get',url )



loadFile( url, true, ->
	callbacks.onNewEvent()   
	init()
	callbacks.onNewDetector()
	render()
	animate()
	)
		



