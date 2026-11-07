// Space Invaders — native Cocoa GUI, C++17 / Objective-C++
// © AC Kondo 1999–2026
#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#include <memory>
#include <algorithm>
#include <cmath>
#include <random>
#include <vector>

constexpr int GW=600, GH=400;
enum class Screen {Menu, Play, Help, About};
static Screen screenMode=Screen::Menu;
static int menuChoice=0;
static const char *menuNames[]={"PLAY","HELP","ABOUT","EXIT"};
static bool audioEnabled=true;
static AVAudioEngine *audioEngine=nil;
static AVAudioPlayerNode *audioNode=nil;
static AVAudioFormat *audioFormat=nil;
static void tone(float hz,float seconds,int kind=0){
 if(!audioEnabled||!audioNode||!audioFormat)return;
 const int rate=22050; AVAudioFrameCount count=(AVAudioFrameCount)(seconds*rate);
 AVAudioPCMBuffer *buf=[[AVAudioPCMBuffer alloc]initWithPCMFormat:audioFormat frameCapacity:count];
 buf.frameLength=count; float *samples=buf.floatChannelData[0];
 for(AVAudioFrameCount i=0;i<count;i++){float t=(float)i/rate;float phase=fmodf(t*hz,1.f);
 float wave=kind==1?(4.f*fabsf(phase-.5f)-1.f):(phase<.25f?1.f:-1.f);
 float env=fminf(1.f,(float)(count-i)/250.f);samples[i]=wave*.11f*env;}
 [audioNode scheduleBuffer:buf completionHandler:nil];if(!audioNode.isPlaying)[audioNode play];
}
static void initAudio(){
 audioEngine=[AVAudioEngine new];audioNode=[AVAudioPlayerNode new];
 audioFormat=[[AVAudioFormat alloc]initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:22050 channels:1 interleaved:NO];
 [audioEngine attachNode:audioNode];[audioEngine connect:audioNode to:audioEngine.mainMixerNode format:audioFormat];
 NSError *err=nil;[audioEngine startAndReturnError:&err];if(err)NSLog(@"Audio unavailable: %@",err);
}

struct Alien {float x,y;bool alive=true;};
struct Shot {float x,y,vy;bool hostile;};
struct Shield {NSRect rect;int hp=4;};
struct Game {
 std::vector<Alien> aliens; std::vector<Shot> shots; std::vector<Shield> shields;
 std::mt19937 rng{std::random_device{}()};
 float player=GW/2.f;int score=0,lives=3,wave=1,dir=1,tick=0,cooldown=0,invulnerable=0;
 bool left=false,right=false,shoot=false,over=false,paused=false;
 Game(){resetWave();}
 void resetWave(){aliens.clear();shots.clear();shields.clear();for(int r=0;r<4;r++)for(int c=0;c<9;c++)aliens.push_back({90.f+c*46,300.f-r*30,true});for(int i=0;i<3;i++)shields.push_back({NSMakeRect(100+i*170,85,60,14),4});dir=1;tick=0;}
 void reset(){score=0;lives=3;wave=1;player=GW/2.f;over=false;paused=false;cooldown=0;invulnerable=0;resetWave();}
 void step(){if(over||paused)return;if(cooldown>0)--cooldown;if(invulnerable>0)--invulnerable;
  if(left)player-=4.5f;if(right)player+=4.5f;player=std::clamp(player,18.f,GW-18.f);
  if(shoot&&cooldown==0){shots.push_back({player,53,7.f,false});cooldown=13;tone(660,.055);}
  int alive=0;for(auto &a:aliens)if(a.alive)++alive;
  if(!alive){score+=100;++wave;resetWave();tone(880,.15,1);return;}
  if(++tick>=std::max(5,30-wave*2-alive/9)){tick=0;bool edge=false;for(auto &a:aliens)if(a.alive&&(a.x+dir*9>GW-18||a.x+dir*9<18))edge=true;
   if(edge){dir=-dir;for(auto &a:aliens)if(a.alive)a.y-=14;}else for(auto &a:aliens)if(a.alive)a.x+=dir*9;
   if((rng()%3)==0){std::vector<int> live;for(int i=0;i<(int)aliens.size();i++)if(aliens[i].alive)live.push_back(i);if(!live.empty()){auto &a=aliens[live[rng()%live.size()]];shots.push_back({a.x,a.y-12,-4.0f-0.2f*wave,true});}}
  }
  for(auto &s:shots){s.y+=s.vy;if(s.y<0||s.y>GH){s.y=-100;continue;}
   for(auto &h:shields){if(h.hp>0&&NSPointInRect(NSMakePoint(s.x,s.y),h.rect)){--h.hp;s.y=-100;break;}}
   if(s.y<0)continue;
   if(s.hostile){if(invulnerable==0&&std::abs(s.x-player)<17&&s.y>=40&&s.y<=57){--lives;tone(150,.23,1);invulnerable=85;s.y=-100;if(lives<=0)over=true;}}
   else for(auto &a:aliens)if(a.alive&&std::abs(s.x-a.x)<17&&std::abs(s.y-a.y)<13){a.alive=false;score+=10;tone(220,.045);s.y=-100;break;}
  }
  shots.erase(std::remove_if(shots.begin(),shots.end(),[](const Shot&s){return s.y<0||s.y>GH;}),shots.end());
  for(auto &a:aliens)if(a.alive&&a.y<64)over=true;
 }
};
static void fill(NSColor *c,NSRect r){[c setFill];NSRectFill(r);}
static void text(NSString *str,CGFloat x,CGFloat y,CGFloat size,NSColor *color){NSDictionary *attrs=@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:size weight:NSFontWeightBold],NSForegroundColorAttributeName:color};[str drawAtPoint:NSMakePoint(x,y) withAttributes:attrs];}
@interface GameView:NSView
@property(nonatomic,assign) Game *game;
@end
@implementation GameView
- (BOOL)acceptsFirstResponder{return YES;}
- (void)keyDown:(NSEvent *)e{
 NSString *k=e.charactersIgnoringModifiers.lowercaseString;if(!k.length)return;unichar c=[k characterAtIndex:0];
 if(screenMode==Screen::Menu){
  if(c==NSUpArrowFunctionKey||c=='w'){menuChoice=(menuChoice+3)%4;tone(440,.04);}
  else if(c==NSDownArrowFunctionKey||c=='s'){menuChoice=(menuChoice+1)%4;tone(440,.04);}
  else if(c==' '||c=='\r'){tone(660,.08);
   if(menuChoice==0){_game->reset();screenMode=Screen::Play;}
   else if(menuChoice==1)screenMode=Screen::Help;
   else if(menuChoice==2)screenMode=Screen::About;
   else [NSApp terminate:nil];}
  return;
 }
 if(screenMode==Screen::Help||screenMode==Screen::About){if(c==27||c==' '||c=='\r'){screenMode=Screen::Menu;tone(440,.05);}return;}
 if(c==27){screenMode=Screen::Menu;_game->left=_game->right=_game->shoot=false;return;}
 if(c=='p'&&!e.isARepeat){_game->paused=!_game->paused;tone(440,.07);}
 if(c=='r'&&_game->over){_game->reset();tone(660,.09);}
 if(c=='a'||c==NSLeftArrowFunctionKey)_game->left=true;
 else if(c=='d'||c==NSRightArrowFunctionKey)_game->right=true;
 else if(c==' ')_game->shoot=true;
}
- (void)keyUp:(NSEvent *)e{NSString *k=e.charactersIgnoringModifiers.lowercaseString;if(!k.length)return;unichar c=[k characterAtIndex:0];if(c=='a'||c==NSLeftArrowFunctionKey)_game->left=false;else if(c=='d'||c==NSRightArrowFunctionKey)_game->right=false;else if(c==' ')_game->shoot=false;}
- (void)mouseDown:(NSEvent *)e{
 NSPoint pt=[self convertPoint:e.locationInWindow fromView:nil];
 if(screenMode==Screen::Menu){for(int i=0;i<4;i++){NSRect r=NSMakeRect(190,215-i*47,220,37);if(NSPointInRect(pt,r)){menuChoice=i;tone(660,.07);if(i==0){_game->reset();screenMode=Screen::Play;}else if(i==1)screenMode=Screen::Help;else if(i==2)screenMode=Screen::About;else [NSApp terminate:nil];break;}}}
 else if(screenMode==Screen::Help||screenMode==Screen::About)screenMode=Screen::Menu;
}
- (void)drawRect:(NSRect)dirty{(void)dirty;fill([NSColor colorWithCalibratedRed:.025 green:.035 blue:.085 alpha:1],self.bounds);
  if(screenMode==Screen::Menu){
  text(@"CAT'S SPACE INVADERS 0.1",94,326,25,NSColor.systemGreenColor);
  text(@"FAMICOM-STYLE ARCADE  |  60 FPS",151,295,12,NSColor.systemYellowColor);
  for(int i=0;i<4;i++){NSRect r=NSMakeRect(190,215-i*47,220,37);
   fill(i==menuChoice?[NSColor colorWithCalibratedRed:.1 green:.45 blue:.2 alpha:1]:[NSColor colorWithCalibratedWhite:.14 alpha:1],r);
   text([NSString stringWithFormat:@"%@ %@",i==menuChoice?@">":@" ",[NSString stringWithUTF8String:menuNames[i]]],235,224-i*47,19,NSColor.whiteColor);}
  text(@"AC KONDO 1999-2026  |  FAN-MADE",150,15,12,NSColor.lightGrayColor);return;
 }
 if(screenMode==Screen::Help||screenMode==Screen::About){
  text(screenMode==Screen::Help?@"HELP":@"ABOUT",245,320,27,NSColor.systemGreenColor);
  if(screenMode==Screen::Help){text(@"A / D OR ARROWS  -  MOVE",115,250,17,NSColor.whiteColor);text(@"SPACE  -  FIRE",115,218,17,NSColor.whiteColor);text(@"P  -  PAUSE     R  -  RESTART",115,186,16,NSColor.whiteColor);text(@"ESC  -  MAIN MENU",115,154,17,NSColor.whiteColor);}
  else {text(@"CAT'S SPACE INVADERS 0.1",115,250,18,NSColor.whiteColor);text(@"C++17 / APPLE SILICON / COCOA",115,215,15,NSColor.whiteColor);text(@"ORIGINAL FAMICOM-STYLE CHIP AUDIO",115,182,13,NSColor.whiteColor);text(@"(C) AC KONDO 1999-2026",115,149,16,NSColor.systemYellowColor);}
  text(@"ENTER / ESC / CLICK TO RETURN",142,54,13,NSColor.lightGrayColor);return;
 }
 auto &g=*_game;text([NSString stringWithFormat:@"SCORE %06d",g.score],18,GH-28,16,NSColor.whiteColor);text([NSString stringWithFormat:@"LIVES %d   WAVE %d",g.lives,g.wave],365,GH-28,14,NSColor.whiteColor);
  fill([NSColor colorWithCalibratedRed:.18 green:.7 blue:.34 alpha:1],NSMakeRect(0,34,GW,2));
  for(auto &a:g.aliens)if(a.alive){NSColor *c=[NSColor colorWithCalibratedRed:.35 green:.95 blue:.5 alpha:1];fill(c,NSMakeRect(a.x-14,a.y-8,28,16));fill(c,NSMakeRect(a.x-10,a.y-12,5,5));fill(c,NSMakeRect(a.x+5,a.y-12,5,5));fill(NSColor.blackColor,NSMakeRect(a.x-7,a.y,4,4));fill(NSColor.blackColor,NSMakeRect(a.x+4,a.y,4,4));}
  for(auto &h:g.shields)if(h.hp>0){CGFloat a=.2+.16*h.hp;fill([NSColor colorWithCalibratedRed:.2 green:.9 blue:.5 alpha:a],h.rect);}
  for(auto &s:g.shots)fill(s.hostile?NSColor.systemRedColor:NSColor.systemYellowColor,NSMakeRect(s.x-2,s.y-6,4,12));
  if(g.invulnerable%8<4) {NSColor *c=NSColor.systemCyanColor;fill(c,NSMakeRect(g.player-15,42,30,10));fill(c,NSMakeRect(g.player-9,52,18,7));fill(c,NSMakeRect(g.player-3,59,6,5));}
  text(@"A/D MOVE  SPACE FIRE  P PAUSE  ESC MENU",18,10,11,NSColor.lightGrayColor);
  if(g.over||g.paused){fill([NSColor colorWithCalibratedWhite:0 alpha:.75],NSMakeRect(0,155,GW,100));text(g.over?@"GAME OVER":@"PAUSED",215,208,24,NSColor.systemYellowColor);text(g.over?@"Press R to restart":@"Press P to resume",208,177,14,NSColor.whiteColor);}
}
@end
@interface AppDelegate:NSObject<NSApplicationDelegate>
@property(nonatomic,strong)NSWindow *window;
@property(nonatomic,strong)GameView *view;
@property(nonatomic,strong)NSTimer *timer;
@end
@implementation AppDelegate {Game game;}
- (void)applicationDidFinishLaunching:(NSNotification *)n{(void)n;
 self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,GW,GH) styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable) backing:NSBackingStoreBuffered defer:NO];
 [self.window setTitle:@"Cat's Space Invaders 0.1"];[self.window center];
 self.view=[[GameView alloc]initWithFrame:NSMakeRect(0,0,GW,GH)];self.view.game=&game;[self.window setContentView:self.view];[self.window makeKeyAndOrderFront:nil];[self.window makeFirstResponder:self.view];
 initAudio();
 self.timer=[NSTimer scheduledTimerWithTimeInterval:1.0/60.0 repeats:YES block:^(NSTimer *t){(void)t;if(screenMode==Screen::Play)game.step();[self.view setNeedsDisplay:YES];}];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{(void)sender;return YES;}
@end
int main(int argc,char **argv){(void)argc;(void)argv;@autoreleasepool{NSApplication *app=[NSApplication sharedApplication];[app setActivationPolicy:NSApplicationActivationPolicyRegular];AppDelegate *delegate=[AppDelegate new];app.delegate=delegate;[app activateIgnoringOtherApps:YES];[app run];}return 0;}
