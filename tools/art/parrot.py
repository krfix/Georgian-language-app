# The Ara parrot: a macaw whose head, neck and curled body draw the letter ა.
# parrot(bg=True) is the app icon (on a Saperavi-to-Black-Sea gradient); bg=False is the
# mascot on a clear background. Used by make_art.py.
from PIL import Image, ImageDraw, ImageFilter
import math
S=1024
def lerp(a,b,t): return a+(b-a)*t
def mix(c1,c2,t): return tuple(int(lerp(c1[i],c2[i],t)) for i in range(len(c1)))
def bez(pts,t):
    while len(pts)>1: pts=[(lerp(pts[i][0],pts[i+1][0],t),lerp(pts[i][1],pts[i+1][1],t)) for i in range(len(pts)-1)]
    return pts[0]
def curve(segs,n=200):
    out=[]
    for s in segs:
        for i in range(n): out.append(bez(s,i/n))
    return out
class SD:
    def __init__(self, im, k): self.d=ImageDraw.Draw(im); self.k=k
    def ellipse(self, box, fill=None, outline=None):
        if fill is None: return
        self.d.ellipse(tuple(v*self.k for v in box), fill=fill)
    def polygon(self, pts, fill=None):
        self.d.polygon([(x*self.k,y*self.k) for x,y in pts], fill=fill)
K=2
def parrot(bg=True, size=S):
    im=Image.new("RGBA",(S*K,S*K),(0,0,0,0))
    if bg:
        g=Image.new("RGB",(S,S)); px=g.load()
        c1=(122,59,194); c2=(21,136,163)
        for y in range(S):
            for x in range(S):
                t=(x*0.4+y)/(1.4*S); px[x,y]=mix(c1,c2,t)
        im=g.convert("RGBA")
        glow=Image.new("L",(S,S),0); ImageDraw.Draw(glow).ellipse((200,150,880,830),fill=120)
        im=Image.composite(Image.new("RGBA",(S,S),(255,170,120,255)),im,glow.filter(ImageFilter.GaussianBlur(160)))
        im=im.resize((S*K,S*K))
    d=SD(im,K)
    # tail feathers (behind body), from the bottom of the curl down-left
    base=(470,700)
    feathers=[((60,150,230),(70,210,250), -0.55, 330, 52),((40,180,120),(110,220,140),-0.85,300,46),((245,180,40),(255,215,90),-0.25,270,40)]
    for c_a,c_b,ang,length,wid in feathers:
        dirx,diry=math.sin(ang),math.cos(ang)
        tip=(base[0]+dirx*length, base[1]+diry*length)
        for i in range(60):
            t=i/59; x=lerp(base[0],tip[0],t); y=lerp(base[1],tip[1],t)
            r=wid*(1-t*0.75)
            d.ellipse((x-r,y-r,x+r,y+r),fill=mix(c_a,c_b,t)+(255,))
    # body: the ა curve as a thick tube, thin neck -> round belly -> wing tip
    segs=[[(505,330),(540,400),(640,470),(630,580)],[(630,580),(620,690),(470,720),(430,640)],[(430,640),(405,590),(420,545),(440,520)]]
    pts=curve(segs)
    n=len(pts)
    for i,(x,y) in enumerate(pts):
        t=i/(n-1)
        r= 62+70*math.sin(min(1,t*1.15)*math.pi)**1.2 if t<0.85 else 62*(1-(t-0.85)/0.15)+18
        col=mix((226,40,60),(255,120,40),min(1,t*1.6)) if t<0.62 else mix((255,120,40),(255,195,60),(t-0.62)/0.38)
        d.ellipse((x-r,y-r,x+r,y+r),fill=col+(255,))
    # wing: blue/green feathers over the belly, along the curve
    for k,(c,off) in enumerate([((30,120,210),0),((40,170,130),24),((250,200,60),48)]):
        wpts=curve([[(600,520-off*0.2),(610,620),(520,690-off*0.3),(470,640-off*0.5)]],60)
        for i,(x,y) in enumerate(wpts):
            t=i/59; r=(34-k*6)*(1-0.5*t)
            d.ellipse((x-r-off*0.4,y-r-off*0.6,x+r-off*0.4,y+r-off*0.6),fill=c+(255,))
    # head
    hx,hy=505,300; R=108
    d.ellipse((hx-R,hy-R,hx+R,hy+R),fill=(232,44,66,255))
    # white face patch with eye
    d.ellipse((hx+5,hy-55,hx+85,hy+25),fill=(255,248,240,255))
    d.ellipse((hx+30,hy-32,hx+68,hy+6),fill=(30,20,30,255))
    d.ellipse((hx+44,hy-26,hx+56,hy-14),fill=(255,255,255,255))
    # beak: a smooth hook, ivory upper part curling over a dark lower part
    lower=curve([[(hx+92,hy+38),(hx+120,hy+40),(hx+128,hy+70),(hx+112,hy+88)],[(hx+112,hy+88),(hx+98,hy+80),(hx+92,hy+60),(hx+92,hy+38)]],40)
    d.polygon(lower,fill=(55,38,50,255))
    upper=curve([[(hx+66,hy-28),(hx+150,hy-40),(hx+196,hy+40),(hx+150,hy+112)],[(hx+150,hy+112),(hx+156,hy+60),(hx+130,hy+30),(hx+80,hy+40)],[(hx+80,hy+40),(hx+70,hy+20),(hx+66,hy),(hx+66,hy-28)]],50)
    d.polygon(upper,fill=(255,238,205,255))
    tip=curve([[(hx+150,hy+112),(hx+168,hy+80),(hx+170,hy+60),(hx+162,hy+48)],[(hx+162,hy+48),(hx+152,hy+70),(hx+148,hy+90),(hx+150,hy+112)]],30)
    d.polygon(tip,fill=(70,50,60,255))
    return im.resize((S,S), Image.LANCZOS)
if __name__ == "__main__":
    parrot().convert("RGB").save("icon.png")
    parrot(bg=False).save("mascot.png")
