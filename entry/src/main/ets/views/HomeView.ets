import { AppModel } from '../app/AppModel';
import { CreatureState } from '../core/LifeEngine';
import { moodInfo } from '../core/Mood';
import { LevelInfo, NextAction, WeekStats, formatSteps, levelFor, timeOfDayGreeting } from '../core/Plan';
import { GROUPS } from '../core/Types';
import { Achievement } from '../core/Achievements';
import { SPECIES, findSpecies } from '../core/Species';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { ActivityDots, Button56, IconButton, MetricBar, Reveal, RingNumber, Tag, Tile, TitleBlock } from '../ui/Kit';
import {
  ACCENT, ACCENT_TINT, BG, F_BOLD, F_REG, GAP, PAD, STAGGER, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE, TRACK, ACCENT_LOW, ACCENT_MID
} from '../ui/Theme';
import { motionOn } from '../ui/Motion';

const GROUP_NAMES: string[] = ['Legs', 'Push', 'Pull', 'Core'];
const WEEK_LETTERS: string[] = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

@Component
export struct HomeView {
  @Prop @Watch('reload') version: number = 0;
  @Prop @Watch('scrollTop') topSignal: number = 0;
  private scroller: Scroller = new Scroller();
  holder: LookHolder = new LookHolder();
  onNavigate: (target: string) => void = () => {};
  @State state: CreatureState = new CreatureState();
  @State name: string = 'Wisp';
  @State demo: boolean = false;
  @State steps: number = 0;
  @State stepGoal: number = 8000;
  @State weeklyGoal: number = 3;
  @State days: number[] = [];
  @State todayIndex: number = -1;
  @State week: WeekStats = new WeekStats();
  @State action: NextAction = new NextAction();
  @State greeting: string = '';
  @State loaded: boolean = false;
  // Tiles are added over three frames: on slow (software-rendered) devices building every
  // tile in the first frame took longer than the system's 6 s main-thread watchdog.
  @State stage: number = 0;
  @State badgesDone: number = 0;
  @State level: LevelInfo = new LevelInfo();
  @State speciesName: string = 'Wisp';
  @State badgesTotal: number = 0;
  @State creaturesOpen: number = 1;
  @State nextBadge: string = '';
  @State nextDetail: string = '';
  @State nextPct: number = 0;

  aboutToAppear(): void {
    this.reload();
    setTimeout(() => {
      this.stage = 1;
      setTimeout(() => {
        this.stage = 2;
      }, 120);
    }, 120);
  }

  // Tapping the active tab again returns to the top, as in platform apps.
  scrollTop(): void {
    this.scroller.scrollEdge(Edge.Top);
  }

  reload(): void {
    const model = AppModel.get();
    const p = model.profile();
    this.name = p.name;
    this.stepGoal = p.stepGoal;
    this.weeklyGoal = p.weeklyGoal;
    this.demo = model.isDemo();
    this.greeting = timeOfDayGreeting(Date.now());
    this.loadCollection();
    this.level = levelFor(model.totalReps());
    this.speciesName = findSpecies(p.species).name;
    // Show the cached state at once, then refine with a fresh step reading.
    this.apply(model.evaluateNow(), model.stepsToday());
    model.state().then((st: CreatureState) => {
      this.apply(st, model.stepsToday());
      model.pushWidget();
    });
  }

  private apply(st: CreatureState, steps: number): void {
    const model = AppModel.get();
    this.state = st;
    this.steps = steps;
    this.week = model.weekStats();
    this.action = model.nextAction(st);
    // Dot calendar: whole weeks (Monday first) ending with the current week.
    const dow = this.week.todayIndex;
    const past = model.repsPerDay(28 + dow + 1);
    for (let i = dow + 1; i < 7; i++) {
      past.push(-1);
    }
    this.days = past;
    this.todayIndex = 28 + dow;
    this.holder.set(model.lookFor(st), !this.loaded);
    this.loaded = true;
  }

  // The closest badge still to earn drives the "next badge" line on the collection tile.
  private loadCollection(): void {
    const model = AppModel.get();
    const list: Achievement[] = model.achievements();
    let done = 0;
    let best: Achievement | null = null;
    for (let i = 0; i < list.length; i++) {
      const a = list[i];
      if (a.unlocked) {
        done++;
      } else if (best === null || a.progress / a.goal > best.progress / best.goal) {
        best = a;
      }
    }
    this.badgesDone = done;
    this.badgesTotal = list.length;
    this.creaturesOpen = model.unlockedSpecies().length;
    if (best !== null) {
      this.nextBadge = best.title;
      this.nextDetail = best.detail;
      this.nextPct = Math.min(1, best.progress / best.goal);
    } else {
      this.nextBadge = '';
    }
  }

  private activeDays(): number {
    let n = 0;
    for (let i = 0; i < this.days.length; i++) {
      if (this.days[i] > 0) {
        n++;
      }
    }
    return n;
  }

  private recoverySub(): string {
    if (this.state.hoursSinceLast < 0) {
      return 'No sessions yet';
    }
    if (this.state.recover >= 1) {
      return 'Fully recovered';
    }
    const h = Math.ceil(this.state.hoursToFull);
    return 'Full in ' + h + ' h';
  }

  private go(): void {
    const t = this.action.target;
    this.onNavigate(t === 'train' ? 'train:' + this.action.exercise : t);
  }

  private actionIcon(): Resource {
    const k = this.action.kind;
    if (k === 'rest' || k === 'recharge') {
      return $r('app.media.ic_moon_accent');
    }
    if (k === 'done' || k === 'bonus') {
      return $r('app.media.ic_trophy_accent');
    }
    return $r('app.media.ic_bolt_accent');
  }

  @Builder
  Header() {
    Row({ space: 10 }) {
      Column() {
        Text(this.greeting)
          .fontSize(14)
          .fontFamily(F_REG)
          .fontColor(TEXT_MUTE)
        Text(this.name)
          .fontSize(32)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.demo) {
        Tag({ text: 'DEMO', accent: true })
      }
      IconButton({ icon: $r('app.media.ic_trophy'), label: 'Collection', onTap: () => this.onNavigate('collection') })
      IconButton({ icon: $r('app.media.ic_sliders'), label: 'Settings', onTap: () => this.onNavigate('settings') })
    }
    .width('100%')
    .margin({ top: 8, bottom: 16 })
  }

  @Builder
  CreatureTile() {
    Tile({ pad: 16 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 230, tappable: true })
        Text('Lv ' + this.level.level)
          .fontSize(12)
          .fontFamily(F_BOLD)
          .fontColor(ACCENT)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor(ACCENT_TINT)
          .margin({ top: 4, left: 4 })
      }
      .width('100%')
      Row({ space: 12 }) {
        Column() {
          Text(moodInfo(this.state.mood).label)
            .fontSize(22)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
          Text(this.state.headline)
            .fontSize(13)
            .fontFamily(F_REG)
            .fontColor(TEXT_DIM)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 4 })
      Column({ space: 6 }) {
        Row() {
          Text(this.speciesName + '  ·  level ' + this.level.level)
            .fontSize(12)
            .fontFamily(F_BOLD)
            .fontColor(TEXT_DIM)
            .layoutWeight(1)
          Text(this.level.into + ' / ' + this.level.need + ' XP')
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
        }
        .width('100%')
        Progress({ value: Math.round(100 * this.level.into / this.level.need), total: 100, type: ProgressType.Linear })
          .width('100%')
          .color(ACCENT)
          .backgroundColor(TRACK)
          .style({ strokeWidth: 4, strokeRadius: 2, enableSmoothEffect: motionOn() })
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 12 })
    }
  }

  @Builder
  ActionCard() {
    Tile({ pad: 18, highlight: true, tappable: true, onTap: () => this.go() }) {
      Row({ space: 14 }) {
        Image(this.actionIcon())
          .width(44)
          .height(44)
          .padding(11)
          .borderRadius(22)
          .backgroundColor(ACCENT_TINT)
        Column() {
          Text(this.action.title)
            .fontSize(17)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
          Text(this.action.detail)
            .fontSize(13)
            .fontFamily(F_REG)
            .fontColor(TEXT_DIM)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      Column() {
        Button56({
          label: this.action.cta,
          kind: this.action.target === 'train' ? 'primary' : 'secondary',
          height56: 46,
          onTap: () => this.go()
        })
      }
      .width('100%')
      .margin({ top: 14 })
    }
  }

  @Builder
  StatRow() {
    Row({ space: GAP }) {
      Column() {
        Tile({ pad: 18, tappable: true, onTap: () => this.onNavigate('insights') }) {
          RingNumber({ value: this.state.train, diameter: 64 })
          Blank().height(14)
          TitleBlock({ title: 'Strength', subtitle: 'Avg. muscle level' })
        }
      }
      .layoutWeight(1)
      Column() {
        Tile({ pad: 18, tappable: true, onTap: () => this.onNavigate('insights') }) {
          RingNumber({
            value: this.steps >= 0 ? this.state.move : 0,
            diameter: 64,
            text: this.steps >= 0 ? formatSteps(this.steps) : '--',
            color: TEXT
          })
          Blank().height(14)
          TitleBlock({
            title: 'Move',
            subtitle: this.steps >= 0 ? 'of ' + formatSteps(this.stepGoal) + ' steps' : 'Step sensor off'
          })
        }
      }
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  RecoveryTile() {
    Tile({ pad: 20, tappable: true, onTap: () => this.onNavigate('insights') }) {
      Row() {
        TitleBlock({ title: 'Recovery', subtitle: this.recoverySub() })
        Blank()
        Text(Math.round(this.state.recover * 100) + '%')
          .fontSize(32)
          .fontFamily(F_BOLD)
          .fontColor(this.state.restRequested || this.state.recover < 0.25 ? ACCENT : TEXT)
      }
      .width('100%')
      Progress({ value: Math.round(this.state.recover * 100), total: 100, type: ProgressType.Linear })
        .width('100%')
        .color(this.state.restRequested || this.state.recover < 0.25 ? ACCENT : TEXT)
        .backgroundColor(TRACK)
        .style({ strokeWidth: 6, strokeRadius: 3, enableSmoothEffect: motionOn() })
        .margin({ top: 14 })
    }
  }

  @Builder
  WeekTile() {
    Tile({ pad: 20, tappable: true, onTap: () => this.onNavigate('progress') }) {
      Row() {
        TitleBlock({
          title: 'This week',
          subtitle: this.week.sessions >= this.weeklyGoal ? 'Weekly goal reached' :
            (this.weeklyGoal - this.week.sessions) + ' to go for your goal'
        })
        Blank()
        Text(this.week.sessions + '/' + this.weeklyGoal)
          .fontSize(32)
          .fontFamily(F_BOLD)
          .fontColor(this.week.sessions >= this.weeklyGoal ? ACCENT : TEXT)
      }
      .width('100%')
      Row() {
        ForEach(WEEK_LETTERS, (d: string, i: number) => {
          Column({ space: 6 }) {
            Stack() {
              if (this.week.days[i]) {
                Image($r('app.media.ic_check_dark')).width(16).height(16)
              }
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(this.week.days[i] ? ACCENT : (i > this.week.todayIndex ? '#00000000' : SURFACE_HI))
            .border({
              width: i === this.week.todayIndex && !this.week.days[i] ? 1.5 : (i > this.week.todayIndex ? 1 : 0),
              color: i === this.week.todayIndex ? TEXT_DIM : TRACK,
              style: i > this.week.todayIndex ? BorderStyle.Dashed : BorderStyle.Solid
            })
            Text(d)
              .fontSize(11)
              .fontFamily(F_BOLD)
              .fontColor(i === this.week.todayIndex ? TEXT : TEXT_MUTE)
          }
        }, (d: string, i: number) => 'w' + i + (this.week.days[i] ? '1' : '0'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 })
    }
  }

  @Builder
  CollectionTile() {
    Tile({ pad: 20, tappable: true, onTap: () => this.onNavigate('collection') }) {
      Row() {
        TitleBlock({
          title: 'Collection',
          subtitle: this.creaturesOpen + ' of ' + SPECIES.length + ' creatures  ·  ' + this.badgesDone + ' of ' +
            this.badgesTotal + ' badges'
        })
        Blank()
        Image($r('app.media.ic_trophy_accent'))
          .width(40)
          .height(40)
          .padding(10)
          .borderRadius(20)
          .backgroundColor(ACCENT_TINT)
      }
      .width('100%')
      if (this.nextBadge.length > 0) {
        Column({ space: 6 }) {
          Row() {
            Text('Next: ' + this.nextBadge).fontSize(13).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
            Text(Math.round(this.nextPct * 100) + '%').fontSize(12).fontFamily(F_BOLD).fontColor(ACCENT)
          }
          .width('100%')
          Progress({ value: Math.round(this.nextPct * 100), total: 100, type: ProgressType.Linear })
            .width('100%')
            .color(ACCENT)
            .backgroundColor(TRACK)
            .style({ strokeWidth: 6, strokeRadius: 3, enableSmoothEffect: motionOn() })
          Text(this.nextDetail).fontSize(12).fontFamily(F_REG).fontColor(TEXT_MUTE).width('100%')
        }
        .width('100%')
        .margin({ top: 14 })
      }
    }
  }

  @Builder
  MusclesTile() {
    Tile({ pad: 20, tappable: true, onTap: () => this.onNavigate('insights') }) {
      TitleBlock({ title: 'Muscle groups', subtitle: 'Each one grows a part of ' + this.name })
      Column({ space: 14 }) {
        ForEach(GROUPS, (g: string, i: number) => {
          MetricBar({
            label: GROUP_NAMES[i],
            value: this.state.levels[i],
            color: this.state.levels[i] >= 0.4 ? TEXT : TEXT_DIM,
            delay: 200 + i * 60
          })
        }, (g: string, i: number) => g + Math.round(this.state.levels[i] * 100))
      }
      .width('100%')
      .margin({ top: 16 })
    }
  }

  @Builder
  ActivityTile() {
    Tile({ pad: 20, tappable: true, onTap: () => this.onNavigate('progress') }) {
      ActivityDots({ values: this.days, todayIndex: this.todayIndex })
      Row() {
        TitleBlock({
          title: 'Last 5 weeks',
          subtitle: this.activeDays() === 0 ? 'Your sessions will light up here' :
            this.activeDays() + (this.activeDays() === 1 ? ' active day' : ' active days')
        })
          .layoutWeight(1)
        Row({ space: 4 }) {
          Text('Less').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE)
          Circle().width(8).height(8).fill(TRACK)
          Circle().width(8).height(8).fill(ACCENT_LOW)
          Circle().width(8).height(8).fill(ACCENT_MID)
          Circle().width(8).height(8).fill(ACCENT)
          Text('More').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
      }
      .width('100%')
      .margin({ top: 18 })
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: GAP }) {
        this.Header()
        Reveal({ delay: 0 }) {
          this.CreatureTile()
        }
        Reveal({ delay: STAGGER }) {
          this.ActionCard()
        }
        if (this.stage >= 1) {
          Reveal({ delay: STAGGER * 2 }) {
            this.StatRow()
          }
          Reveal({ delay: STAGGER * 3 }) {
            this.RecoveryTile()
          }
          Reveal({ delay: STAGGER * 4 }) {
            this.WeekTile()
          }
        }
        if (this.stage >= 2) {
          Reveal({ delay: STAGGER }) {
            this.CollectionTile()
          }
          Reveal({ delay: STAGGER * 2 }) {
            this.MusclesTile()
          }
          Reveal({ delay: STAGGER * 3 }) {
            this.ActivityTile()
          }
        }
        Blank().height(104)
      }
      .padding({ left: PAD, right: PAD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(BG)
  }
}
