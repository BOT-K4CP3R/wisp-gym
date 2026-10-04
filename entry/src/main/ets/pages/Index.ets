import { AppModel, NAV_TARGET } from '../app/AppModel';
import { LookHolder } from '../components/LookHolder';
import { HomeView } from '../views/HomeView';
import { ProgressView } from '../views/ProgressView';
import { InsightsView } from '../views/InsightsView';
import { TabBar } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { RouteParams, navPush } from '../ui/Nav';
import { BG, DUR_FAST, PAD } from '../ui/Theme';
import { anim } from '../ui/Motion';

const TABS: string[] = ['home', 'progress', 'insights'];

// App shell: three tabs that keep their state, a floating tab bar and the workout entry.
@Entry
@Component
struct Index {
  @State tab: string = 'home';
  @State version: number = 0;
  @State topSignal: number = 0;
  // Tabs other than Home are built on first visit, keeping the first frame light.
  @State seenProgress: boolean = false;
  @State seenInsights: boolean = false;
  @StorageProp(NAV_TARGET) @Watch('onNavTarget') navTarget: string = '';
  private homeHolder: LookHolder = new LookHolder();
  private progressHolder: LookHolder = new LookHolder();
  private tabs: TabsController = new TabsController();
  private visible: boolean = false;
  private handledTarget: string = '';

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    this.syncHolders();
    // Ask once, with a stated reason, for the pedometer; the app works without it.
    const model = AppModel.get();
    if (!model.isDemo() && !model.profile().motionAsked) {
      const p = model.profile();
      p.motionAsked = true;
      model.saveProfile(p);
      model.requestMotionPermission().then(() => {
        this.version++;
      });
    }
    this.onNavTarget();
  }

  onPageShow(): void {
    this.visible = true;
    this.version++;
    this.syncHolders();
  }

  onPageHide(): void {
    this.visible = false;
    this.homeHolder.active = false;
    this.progressHolder.active = false;
  }

  // Widget taps arrive as a changing "target@time" value.
  onNavTarget(): void {
    const raw = this.navTarget;
    if (raw.length === 0 || raw === this.handledTarget) {
      return;
    }
    this.handledTarget = raw;
    const target = raw.split('@')[0];
    // A widget tap while a workout, settings or another page is open: stay where the user is.
    let depth = '1';
    try {
      depth = this.getUIContext().getRouter().getLength();
    } catch (e) {
      depth = '1';
    }
    if (depth !== '1' && depth !== '0') {
      return;
    }
    this.navigate(target);
  }

  private syncHolders(): void {
    this.homeHolder.active = this.tab === 'home';
    this.progressHolder.active = this.tab === 'progress';
  }

  private navigate(target: string): void {
    if (target === 'train' || target.startsWith('train:')) {
      const params = new RouteParams();
      if (target.length > 6) {
        params.exercise = target.substring(6);
      }
      navPush(this.getUIContext(), 'pages/Workout', params);
      return;
    }
    if (target === 'settings') {
      navPush(this.getUIContext(), 'pages/Settings');
      return;
    }
    if (target === 'body') {
      navPush(this.getUIContext(), 'pages/Body');
      return;
    }
    if (target === 'collection') {
      navPush(this.getUIContext(), 'pages/Collection');
      return;
    }
    const idx = TABS.indexOf(target);
    if (idx < 0) {
      return;
    }
    if (this.tab !== target) {
      AppModel.get().tick(8);
    } else {
      this.topSignal++;
    }
    if (target === 'progress') {
      this.seenProgress = true;
    } else if (target === 'insights') {
      this.seenInsights = true;
    }
    this.tab = target;
    this.tabs.changeIndex(idx);
    this.syncHolders();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ index: TABS.indexOf(this.tab), controller: this.tabs }) {
        TabContent() {
          HomeView({ version: this.version, topSignal: this.topSignal, holder: this.homeHolder, onNavigate: (t: string) => this.navigate(t) })
            .opacity(this.tab === 'home' ? 1 : 0)
            .animation(anim({ duration: DUR_FAST * 1.5, curve: Curve.EaseOut }))
        }
        TabContent() {
          if (this.seenProgress) {
            ProgressView({ version: this.version, topSignal: this.topSignal, active: this.tab === 'progress', holder: this.progressHolder })
              .opacity(this.tab === 'progress' ? 1 : 0)
              .animation(anim({ duration: DUR_FAST * 1.5, curve: Curve.EaseOut }))
          }
        }
        TabContent() {
          if (this.seenInsights) {
            InsightsView({ version: this.version, topSignal: this.topSignal })
              .opacity(this.tab === 'insights' ? 1 : 0)
              .animation(anim({ duration: DUR_FAST * 1.5, curve: Curve.EaseOut }))
          }
        }
      }
      .barHeight(0)
      .scrollable(false)
      .animationDuration(0)
      .width('100%')
      .height('100%')

      // Fade the content out under the floating bar.
      Column() {
        TabBar({ active: this.tab, onNavigate: (t: string) => this.navigate(t) })
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, bottom: 12, top: 24 })
      .linearGradient({ angle: 180, colors: [['#000A0A0C', 0], ['#E60A0A0C', 0.45], [BG, 1]] })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
