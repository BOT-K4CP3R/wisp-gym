import { AppModel } from '../app/AppModel';
import { CreatureState } from '../core/LifeEngine';
import { moodInfo } from '../core/Mood';
import { NextAction, WeekStats, formatSteps, timeOfDayGreeting } from '../core/Plan';
import { GROUPS } from '../core/Types';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { ActivityDots, Button56, IconButton, MetricBar, Reveal, RingNumber, Tag, Tile, TitleBlock } from '../ui/Kit';
import {
  ACCENT, ACCENT_TINT, BG, F_BOLD, F_REG, GAP, PAD, STAGGER, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE, TRACK
} from '../ui/Theme';

const GROUP_NAMES: string[] = ['Legs', 'Push', 'Pull', 'Core'];
const WEEK_LETTERS: string[] = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

@Component
export struct HomeView {
  @Prop @Watch('reload') version: number = 0;
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

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    const model = AppModel.get();
    const p = model.profile();
    this.name = p.name;
    this.stepGoal = p.stepGoal;
    this.weeklyGoal = p.weeklyGoal;
    this.demo = model.isDemo();
    this.greeting = timeOfDayGreeting(Date.now());
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
      IconButton({ icon: $r('app.media.ic_sliders'), label: 'Settings', onTap: () => this.onNavigate('settings') })
    }
    .width('100%')
    .margin({ top: 8, bottom: 16 })
  }

  @Builder
  CreatureTile() {
    Tile({ pad: 16 }) {
      CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 230, tappable: true })
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
        .style({ strokeWidth: 6, strokeRadius: 3, enableSmoothEffect: true })
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
        Blank()
        Row({ space: 4 }) {
          Text('Less').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE)
          Circle().width(8).height(8).fill(TRACK)
          Circle().width(8).height(8).fill('#6B3A28')
          Circle().width(8).height(8).fill('#B8623F')
          Circle().width(8).height(8).fill(ACCENT)
          Text('More').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
      }
      .width('100%')
      .margin({ top: 18 })
    }
  }

  build() {
    Scroll() {
      Column({ space: GAP }) {
        this.Header()
        Reveal({ delay: 0 }) {
          this.CreatureTile()
        }
        Reveal({ delay: STAGGER }) {
          this.ActionCard()
        }
        Reveal({ delay: STAGGER * 2 }) {
          this.StatRow()
        }
        Reveal({ delay: STAGGER * 3 }) {
          this.RecoveryTile()
        }
        Reveal({ delay: STAGGER * 4 }) {
          this.WeekTile()
        }
        Reveal({ delay: STAGGER * 5 }) {
          this.MusclesTile()
        }
        Reveal({ delay: STAGGER * 6 }) {
          this.ActivityTile()
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
