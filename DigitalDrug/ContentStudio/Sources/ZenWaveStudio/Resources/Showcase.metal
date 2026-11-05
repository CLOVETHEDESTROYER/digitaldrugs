// Original ZenWave native showcase. Analytic volumes, lit distance fields and
// layered geometry are deliberately distinct from the feedback-first WebGL set.
float3 showColor(float x) { return 0.52 + 0.47 * cos(float3(0.2, 2.25, 4.3) + x * 6.2831853); }
float2 showRotate(float2 p, float a) { return float2(cos(a)*p.x-sin(a)*p.y,sin(a)*p.x+cos(a)*p.y); }
float showNoise(float3 p) {
    return sin(p.x + sin(p.y * 1.31)) * sin(p.y + sin(p.z * 1.17)) * sin(p.z + sin(p.x * 0.91));
}
float showField(float3 p, float t, int kind) {
    if (kind == 0) {
        // A tilted luminous ring, with a subtly braided tube surface.
        p.yz = showRotate(p.yz, 0.73 + sin(t * 0.08) * 0.12);
        float a = atan2(p.z,p.x);
        float major = 0.30 + sin(a * 6.0 + t * 0.28) * 0.012;
        return length(float2(length(p.xz)-major,p.y))-0.065;
    }
    if (kind == 1) {
        p.xy = showRotate(p.xy, t * 0.07 + p.z * 0.30);
        float3 q = abs(p);
        // Octahedral crystal in a six-fold outer sanctuary.
        return (q.x+q.y+q.z-0.42)*0.57735;
    }
    p.xz = showRotate(p.xz, t * 0.12);
    p.yz = showRotate(p.yz, 0.6);
    float a=atan2(p.z,p.x);
    float3 center=float3(cos(a)*0.29,sin(a*3.0+t*0.24)*0.11,sin(a)*0.29);
    return length(p-center)-0.041;
}
float3 showSculpture(float2 p,float t,float energy,int kind) {
    float3 ro=float3(p*.94,1.45),rd=normalize(float3(p*0.08,-1.0));
    float travel=0.55, closest=1.0;float3 at=float3(0.0);bool hit=false;
    for(int step=0;step<60;step++) {
        at=ro+rd*travel;float d=showField(at,t,kind);closest=min(closest,abs(d));
        if(d<0.0012){hit=true;break;}travel+=max(d*0.7,0.001);
        if(travel>2.3)break;
    }
    float3 color=float3(0.004,0.008,0.025)+showColor(t*.006)*exp(-dot(p,p)*6.0)*.025;
    color+=showColor(t*.015+length(p)*.4)*exp(-closest*90.0)*.10;
    if(hit) {
        float e=.0015;float3 n=normalize(float3(showField(at+float3(e,0,0),t,kind)-showField(at-float3(e,0,0),t,kind),showField(at+float3(0,e,0),t,kind)-showField(at-float3(0,e,0),t,kind),showField(at+float3(0,0,e),t,kind)-showField(at-float3(0,0,e),t,kind)));
        float light=max(dot(n,normalize(float3(-.5,.7,.8))),0.0);
        float rim=pow(1.0-max(dot(n,-rd),0.0),3.0);
        float stripes=pow(.5+.5*sin((at.x+at.y+at.z)*95.0+t*.7),12.0);
        float3 pigment=showColor(dot(at,float3(.7,.6,.4))*.9+t*.014);
        color+=pigment*(.16+light*.7+stripes*.22)*(0.85+energy*.3);
        color+=float3(.55,.85,1.0)*rim*.55+pow(max(dot(reflect(-normalize(float3(-.5,.7,.8)),n),-rd),0.0),38.0)*.8;
        if(kind==1)color+=showColor(at.y*1.9+t*.02)*(.25+rim*.4);
    }
    // Orbital satellite lights, without noise or frame-dependent particle state.
    for(int i=0;i<9;i++) {
        float a=float(i)*6.2831853/9.0+t*.12;
        float2 dotp=showRotate(float2(cos(a)*.39,sin(a)*.18),-.4);
        float d=length(p-dotp);color+=showColor(float(i)/9.0)*exp(-d*d/.00013)*.65;
    }
    return color;
}
float3 showcase(float2 point,constant VisualizerUniforms& u,int kind) {
    float t=u.time,energy=u.level,bass=u.bass;
    float motion=u.motionAmount;
    float2 p=point-float2(sin(t*.10),cos(t*.08))*.009*motion;
    float r=length(p),angle=atan2(p.y,p.x);
    float3 c=float3(.003,.007,.019);
    if(kind==0||kind==1||kind==4) {
        c=showSculpture(p,t,energy,kind);
        if(kind==0) {
            float lens=exp(-pow((r-.31)/.021,2.0));
            c+=float3(.30,.65,1.0)*lens*.18;
            float disk=exp(-pow((length(float2(p.x,p.y*3.8))-.37)/.025,2.0));
            c+=float3(.9,.46,.13)*disk*.25;
        }
        if(kind==1) {
            for(int layer=0;layer<5;layer++) {
                float phase=float(layer)*.7+t*.035;
                float2 q=showRotate(p,phase);float hex=max(abs(q.x)*.866+abs(q.y)*.5,abs(q.y));
                float edge=abs(hex-(.27+float(layer)*.063));
                c+=showColor(float(layer)*.12+t*.006)*exp(-edge*edge/.000025)*(.2+energy*.16);
            }
        }
    } else if(kind==2) {
        // Perspective waves: several translucent ribbons with specular crests.
        for(int layer=0;layer<18;layer++) {
            float z=float(layer)/18.0,scale=.4+z*2.5;
            float x=p.x*scale;
            float height=-.48+z*.76+sin(x*5.0+t*.22+z*7.0)*(.025+motion*.028)+sin(x*11.0-t*.31+z*13.0)*.012;
            float d=p.y-height;
            float width=.0025+fwidth(p.y);
            float crest=exp(-d*d/(width*width*3.0));
            float mist=exp(-abs(d)*35.0)*.045;
            c+=showColor(z*.65+t*.007)*(crest*.28+mist)*(1.0-z*.45)*(0.8+energy*.45);
        }
        c+=float3(.05,.16,.23)*exp(-abs(p.y+.06)*4.0)*.15;
    } else if(kind==3) {
        // Solar photosphere and continuous magnetic arches around its limb.
        float radius=.32+bass*.012,edge=max(fwidth(r),.001);
        float mask=1.0-smoothstep(radius-edge,radius+edge,r);
        float z=sqrt(max(radius*radius-r*r,0.0));
        float3 normal=normalize(float3(p,z+.0001));
        float granule=showNoise(float3(p*65.0,z*65.0+t*.15));
        float photosphere=.45+.3*granule+.2*showNoise(float3(p*125.0,z*80.0-t*.22));
        c+=mix(float3(.98,.18,.05),float3(1.0,.78,.28),photosphere)*mask*(.35+.65*normal.z);
        float corona=exp(-abs(r-radius)*22.0)*(1.0-mask);
        float strands=pow(.5+.5*sin(angle*37.0+sin(r*23.0-t*.25)*1.7+sin(angle*9.0+t*.13)),9.0);
        c+=mix(float3(1.0,.10,.12),float3(1.0,.65,.16),strands)*corona*(.18+strands*.65)*(1.0+energy*.3);
    } else if(kind==5) {
        // Individually rotating translucent petal shells, receding into a deep iris.
        for(int layer=0;layer<11;layer++) {
            float z=float(layer),size=.075+z*.037;
            float a=angle+t*(.028+z*.003)*(z/2.0-floor(z/2.0)<.1?1.0:-1.0);
            float shape=size*(1.0+.19*cos(a*(6.0+2.0*floor(z/4.0))+sin(t*.19+z)*motion*.6));
            float d=r-shape;
            float width=.002+fwidth(r);
            float line=exp(-d*d/(width*width*2.0));
            float veil=exp(-abs(d)*65.0)*.10;
            c+=showColor(z*.1+t*.012)*(line*.48+veil)*(0.75+energy*.3);
        }
        c+=showColor(.6+t*.01)*exp(-r*r*90.0)*.15;
    } else if(kind==6) {
        // Smooth braided light sheets. Sharp inner strands float inside wide silk.
        for(int ribbon=0;ribbon<10;ribbon++) {
            float i=float(ribbon);
            float x=p.x+sin(p.y*3.0+t*.12+i*.43)*(.07+motion*.045);
            float lane=(i-4.5)*.049+sin(p.y*5.0-t*.24+i*.63)*.07;
            float d=x-lane;
            float width=.005+i*.0004;
            float glow=exp(-d*d/(width*width*5.0));
            float filament=exp(-d*d/(.000002+fwidth(p.x)*fwidth(p.x)));
            c+=showColor(i*.095+p.y*.15+t*.01)*(glow*.09+filament*.30)*(0.7+energy*.4);
        }
    } else {
        // Tilted spiral galaxy: luminous core, dust lanes and parallax stars.
        float2 q=showRotate(p,t*.025);q.y*=2.2;
        float gr=length(q),ga=atan2(q.y,q.x);
        float spiral=ga*3.0-log(gr+.025)*5.0-t*.12;
        float arm=pow(.5+.5*cos(spiral),8.0)*exp(-gr*3.0);
        float dust=.55+.45*showNoise(float3(q*24.0,t*.04));
        c+=mix(float3(.22,.18,.65),float3(.12,.55,.72),.5+.5*sin(ga))*arm*dust*2.4;
        c+=float3(1.0,.68,.34)*exp(-gr*gr*150.0)*.75;
        c+=float3(.5,.68,.95)*exp(-gr*gr*20.0)*.22;
        c+=spaceStars(p,t*.65,energy)*.65;
    }
    c*=.85+energy*.26;
    return 1.0-exp(-c*1.65);
}
