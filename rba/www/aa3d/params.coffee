
String.prototype.contains = (it) -> return @indexOf(it) != -1

# 
# - a ^ before the callback name means it onFinishChange will be used


pardesc = """

folder Detector 
 bgColor     def=000022                   callback=setBackgroundColor
 floorColor  def=484830                   callback=addFloor
 floorOpacity def=0.5
 stringColor def=ff00ff
 stringWidth def=2

folder Doms                                callback=addDoms
  showDoms    def=true 
  domColor    def=335588                    
  domSize     def=5         range=[1,15]    
  domDetail   def=9         range=[2,15]    
  domFactor   def=5         range=[2,15]    callback=addDoms,addHits
  domFragmentShader def=fragmentshader_glsl choices=['fragmentshader_antares_glsl','fragmentshader_glsl'] callback=addDoms
  endfolder
 endfolder

folder Tracks                               callback=addTracks
 trackWidth   def=1        range=[.1,5]     
 trackLen     def=20       range=[5,500]
 neuLen       def=5000     range=[100,10000]
 neuColor     def=ffff00
 muColor      def=0000ff
 trackColor   def=00ff00         
 mcTrackColor def=ff0000         
 tracks       def=mc_trks        
endfolder

folder Hits   callback=addHits
 hitStyle     def=cone     choices=['cone','sphere','disk']
 hitDetail    def=8        range=[1,15]
 hitWidth     def=1        range=[0.1,10]
 hitLength    def=1        range=[0.1,10]
 hitSet       def=hits     choices=['hits','mchits','none']
 palette      def=doppler  choices=['doppler','hue']
 ampFunc      def=7*Math.sqrt(hit.tot)
 depthSort    func
 depthSortEvery def=100
endfolder

folder Camera
 camDistance  def=1000     range=[1,10000]  callback=addCamera
 camHeight    def=500      range=[1,1000]   callback=addCamera
endfolder

folder animation
 rotate        def=true    
 rotationSpeed def=2        range=[-20,20]
 animate       def=false
 aniTotFactor  def=5        range=[0.1,10]    callback=addHits
 ns_per_s      def=1000     range=[10,2000]
 introTime     def=0        range=[-3000,1000]
 outroTime     def=0        range=[-3000,1000]
endfolder

screenshot    func
screenshot360 func

demo           def="null"   choices=['null','vr_demo1']

folder network
relay_sever    def="www.cherenkof.nl:8181"
token          def="12345"

endfolder
"""

parse_props = ( lst, obj ) ->
    
    for l in lst
        [k,v] = l.split('=')
        if typeof v == 'undefined' then v = true # no = in l
        obj[k] = v

    if obj.def 
        console.log( obj.name, obj.def )
        if obj.name.contains("olor") and not obj.def.contains("0x")
            obj.def = Number("0x"+obj.def)
        else
            obj.def = Number(obj.def) if !isNaN(obj.def)
            obj.def = true  if obj.def =='true'
            obj.def = false if obj.def =='false'

    if obj.callback and obj.callback.contains(',')
        obj.callback = obj.callback.split(',')        

        

make_parlist = ( desc ) ->

    r = []
    
    for line in desc.split('\n')
    
        v = line.match(/\S+/g) #thank god for stackoverflow
        if not v then continue
        obj = {}
        obj.name = v[0]
        if obj.name == 'folder' 
            obj.folder = v[1] 
            parse_props( v[2..], obj )
            r.push(obj)
            continue

        if obj.name == 'endfolder'
            r.push(obj)
            continue

        parse_props( v[1..], obj ) 
        r.push( obj )
                
    return r





window.buildmenu = (
    parameters         = {} ,
    callback_functions = {} ,
    parlist            = make_parlist( pardesc ) ) ->
    console.log ("dsljksjkgls")
    
    parameters.__callbacks = {}
    parameters.__controllers = {}

    r = new dat.GUI
    menu_stack = [ r ]
    
    for par, i in parlist

        gui = menu_stack[-1..][0]

        if not gui 
            console.log("too many endfolder")

        if par.name == 'folder'         
            f = gui.addFolder( par.folder )
            if par.callback then f.callback = par.callback
            menu_stack.push( f )
            continue
            
        if par.name == 'endfolder'
            menu_stack.pop()
            continue

        if par.func
            gui.add( callback_functions , par.name )
            continue

        if par.name

            parameters[par.name] = par.def

            if par.name.contains("Color") or par.name.contains("color")
                try 
                    item = gui.addColor( parameters, par.name )
                catch error
                    console.log("error setting color", par.name , parameters[par.name] )
                
            else
                if par.range
                    par.range = eval(par.range)
                    item = gui.add(parameters, par.name, par.range[0], par.range[1] );

                if par.choices
                	
                    console.log("aaa", par.name, parameters[par.name] )
                    item = gui.add(parameters, par.name, eval( par.choices ) )
    
                if not par.range and not par.choices
                    item = gui.add(parameters, par.name)

            cb = par.callback or gui.callback
            console.log(cb)
            
            if not cb then continue
            #console.log(cb)

            if Array.isArray( cb ) 
                cb_ = do (cb) -> -> callback_functions[x]() for x in cb
            else
                cb_ = callback_functions[cb]

            item.onChange( cb_ )
            parameters.__callbacks[ par.name ]   = cb_
            parameters.__controllers[ par.name ] = item
     
     
    parameters.set = (name, value ) ->
        this[name] = value
        this.__callbacks[name]?()
        this.__controllers[name]?.updateDisplay()
        
    return r

window.updateGui = (gui) ->
    
    if gui.__folders? then for k,v of gui.__folders 
        updateGui( v )
    
    for c in gui.__controllers 
        c.updateDisplay()


`
window.updateGui_ = function ( gui ) {

for (var i = 0; i < Object.keys(gui.__folders).length; i++) {

    var key = Object.keys(gui.__folders)[i];
    for (var j = 0; j < gui.__folders[key].__controllers.length; j++ )
    {
        gui.__folders[key].__controllers[j].updateDisplay();
    }
}
}
`

