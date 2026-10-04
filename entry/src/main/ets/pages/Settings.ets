import { AppModel } from '../app/AppModel';
import { NAME_MAX, Profile, reducedMotion, STEP_GOAL_MAX, STEP_GOAL_MIN, WEEKLY_GOAL_MAX, WEEKLY_GOAL_MIN, sanitizeName } from '../core/Profile';
import { formatSteps, plural } from '../core/Plan';
import { findSpecies } from '../core/Species';
import { Button56, IconButton, NavRow, SectionLabel, Tile } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { RouteParams, navPush, navReplace } from '../ui/Nav';
import { ACCENT, BG, F_BOLD, F_REG, HAIRLINE, PAD, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE } from '../ui/Theme';

const APP_VERSION = '1.3.1';

@Entry
@Component
struct Settings {
  @State stage: number = 0;
  @State profile: Profile = new Profile();
  @State demo: boolean = false;
  @State workouts: number = 0;
  @State showName: boolean = false;
  @State draftName: string = '';
  @State confirm: string = '';          // '' | 'sample' | 'erase'
  @State showConfirm: boolean = false;

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    // Lower sections are built in the next frame: on slow (software-rendered) devices one
    // big first frame can exceed the system's 6 s main-thread watchdog.
    setTimeout(() => {
      this.stage = 1;
    }, 120);
    this.load();
  }

  // Back from the replayed introduction: show the possibly renamed creature and goals.
  onPageShow(): void {
    this.load();
  }

  private load(): void {
    const m = AppModel.get();
    this.profile = m.profile();
    this.demo = m.isDemo();
    this.workouts = m.workouts().length;
  }

  private save(p: Profile): void {
    AppModel.get().saveProfile(p);
    this.load();
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (e) {
      // toasts are cosmetic
    }
  }

  private setWeekly(delta: number): void {
    const p = this.profile;
    const v = Math.min(WEEKLY_GOAL_MAX, Math.max(WEEKLY_GOAL_MIN, p.weeklyGoal + delta));
    if (v === p.weeklyGoal) {
      return;
    }
    p.weeklyGoal = v;
    this.save(p);
    AppModel.get().tick(10);
  }

  private setSteps(delta: number): void {
    const p = this.profile;
    const v = Math.min(STEP_GOAL_MAX, Math.max(STEP_GOAL_MIN, p.stepGoal + delta));
    if (v === p.stepGoal) {
      return;
    }
    p.stepGoal = v;
    this.save(p);
    AppModel.get().tick(10);
  }

  private ask(kind: string): void {
    this.confirm = kind;
    this.showConfirm = true;
  }

  private runConfirm(): void {
    const m = AppModel.get();
    const router = this.getUIContext().getRouter();
    if (this.confirm === 'sample') {
      m.loadDemoHistory();
      setTimeout(() => this.toast('Loaded 14 days of simulated history'), 400); // after the sheet closes
    } else if (this.confirm === 'demo-off' || this.confirm === 'demo-keep') {
      if (this.confirm === 'demo-off') {
        m.resetHistory();
      }
      m.setDemo(false);
      setTimeout(() => this.toast('Demo mode off: real sensors'), 400);
    } else if (this.confirm === 'erase') {
      m.resetAll();
      this.showConfirm = false;
      router.clear();
      navReplace(this.getUIContext(), 'pages/Onboarding');
      return;
    }
    this.showConfirm = false;
    this.load();
  }

  private confirmTitle(): string {
    if (this.confirm === 'erase') {
      return 'Erase all data?';
    }
    if (this.confirm === 'demo-off') {
      return 'Turn off Demo mode?';
    }
    return 'Load sample data?';
  }

  private confirmBody(): string {
    if (this.confirm === 'erase') {
      return 'All workouts, body weight, badges, your creature and your settings are deleted from this phone. ' +
        'This cannot be undone.';
    }
    if (this.confirm === 'demo-off') {
      return 'Your history contains simulated sample training. Clear it to start your real history, or keep it.';
    }
    return (this.workouts > 0 ? 'Your ' + plural(this.workouts, 'workout') + ' will be replaced by ' :
      'This adds ') + '14 days of clearly labelled simulated training and turns on Demo mode.';
  }

  private isOn(key: string): boolean {
    if (key === 'haptics') {
      return this.profile.haptics;
    }
    if (key === 'restAlerts') {
      return this.profile.restAlerts;
    }
    if (key === 'motion') {
      return reducedMotion(this.profile.motion, AppModel.get().softwareRenderer());
    }
    return this.demo;
  }

  private toggle(key: string, v: boolean): void {
    if (key === 'demo') {
      if (!v && AppModel.get().hasSampleHistory()) {
        // Sample training would otherwise stay mixed into real progress.
        this.ask('demo-off');
        return;
      }
      AppModel.get().setDemo(v);
      this.load();
      this.toast(v ? 'Demo mode on: sensors are simulated' : 'Demo mode off: real sensors');
      return;
    }
    const p = this.profile;
    if (key === 'motion') {
      p.motion = v ? 'reduced' : 'full';
      this.save(p);
      return;
    }
    if (key === 'haptics') {
      p.haptics = v;
    } else {
      p.restAlerts = v;
    }
    this.save(p);
    if (v) {
      AppModel.get().tick(20);
    }
  }

  private stepperValue(key: string): string {
    return key === 'weekly' ? '' + this.profile.weeklyGoal : formatSteps(this.profile.stepGoal);
  }

  @Builder
  ToggleRow(title: string, sub: string, key: string, divider: boolean) {
    Column() {
      Row({ space: 12 }) {
        Column() {
          Text(title).fontSize(16).fontFamily(F_BOLD).fontColor(TEXT)
          Text(sub)
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.isOn(key) })
          .selectedColor(ACCENT)
          .switchPointColor('#FFFFFF')
          .accessibilityText(title)
          .onChange((v: boolean) => this.toggle(key, v))
      }
      .width('100%')
      .constraintSize({ minHeight: 64 })
      .padding({ top: 8, bottom: 8 })
      if (divider) {
        Divider().color(HAIRLINE).strokeWidth(1)
      }
    }
  }

  @Builder
  StepperRow(title: string, key: string, divider: boolean) {
    Column() {
      Row({ space: 10 }) {
        Text(title).fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1).maxLines(1)
        IconButton({ icon: $r('app.media.ic_minus'), label: 'Decrease ' + title, diameter: 40, onTap: () => {
          if (key === 'weekly') {
            this.setWeekly(-1);
          } else {
            this.setSteps(-1000);
          }
        } })
        Text(this.stepperValue(key))
          .fontSize(17)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .width(44)
          .textAlign(TextAlign.Center)
        IconButton({ icon: $r('app.media.ic_plus'), label: 'Increase ' + title, diameter: 40, onTap: () => {
          if (key === 'weekly') {
            this.setWeekly(1);
          } else {
            this.setSteps(1000);
          }
        } })
      }
      .width('100%')
      .height(64)
      if (divider) {
        Divider().color(HAIRLINE).strokeWidth(1)
      }
    }
  }

  @Builder
  NameSheet() {
    Column({ space: 14 }) {
      Text('Rename your creature').fontSize(22).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
      TextInput({ text: this.draftName, placeholder: 'Wisp' })
        .maxLength(NAME_MAX)
        .height(52)
        .fontSize(18)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .placeholderColor(TEXT_MUTE)
        .caretColor(ACCENT)
        .backgroundColor(SURFACE_HI)
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
        .enterKeyType(EnterKeyType.Done)
        .onChange((v: string) => {
          this.draftName = v;
        })
        .onSubmit(() => this.saveName())
      Button56({ label: 'Save', active: this.draftName.trim().length > 0, onTap: () => this.saveName() })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 36 })
  }

  private saveName(): void {
    const p = this.profile;
    p.name = sanitizeName(this.draftName);
    this.save(p);
    this.showName = false;
    this.toast('Say hi to ' + p.name);
  }

  @Builder
  ConfirmSheet() {
    Column({ space: 10 }) {
      Text(this.confirmTitle())
        .fontSize(22)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
      Text(this.confirmBody())
        .fontSize(14)
        .fontFamily(F_REG)
        .fontColor(TEXT_DIM)
        .width('100%')
        .margin({ bottom: 8 })
      Button56({
        label: this.confirm === 'erase' ? 'Erase everything' : (this.confirm === 'demo-off' ? 'Clear sample data' :
          'Load sample data'),
        kind: this.confirm === 'erase' ? 'danger' : 'primary',
        onTap: () => this.runConfirm()
      })
      if (this.confirm === 'demo-off') {
        Button56({ label: 'Keep it', kind: 'secondary', onTap: () => {
          this.confirm = 'demo-keep';
          this.runConfirm();
        } })
      }
      Button56({ label: 'Cancel', kind: 'ghost', onTap: () => {
        this.showConfirm = false;
        this.load();
      } })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 36 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        IconButton({ icon: $r('app.media.ic_back'), label: 'Back', onTap: () => this.getUIContext().getRouter().back() })
        Text('Settings').fontSize(22).fontFamily(F_BOLD).fontColor(TEXT)
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 8, bottom: 8 })
      .bindSheet($$this.showConfirm, this.ConfirmSheet(), {
        height: SheetSize.FIT_CONTENT,
        showClose: false,
        dragBar: true,
        backgroundColor: SURFACE
      })

      Scroll() {
        Column() {
          SectionLabel({ text: 'Creature' })
          Tile({ pad: 6 }) {
            Column() {
              NavRow({
                icon: $r('app.media.ic_edit'),
                title: 'Name',
                value: this.profile.name,
                onTap: () => {
                  this.draftName = this.profile.name;
                  this.showName = true;
                }
              })
              NavRow({
                icon: $r('app.media.ic_target'),
                title: 'Body and BMI',
                value: this.profile.heightCm > 0 ? this.profile.heightCm.toFixed(0) + ' cm' : '',
                onTap: () => navPush(this.getUIContext(), 'pages/Body')
              })
              NavRow({
                icon: $r('app.media.ic_trophy'),
                title: 'Collection',
                value: findSpecies(this.profile.species).name,
                divider: false,
                onTap: () => navPush(this.getUIContext(), 'pages/Collection')
              })
            }
            .padding({ left: 14, right: 14 })
          }

          if (this.stage >= 1) {
            SectionLabel({ text: 'Goals' })
            Tile({ pad: 6 }) {
              Column() {
                this.StepperRow('Weekly sessions', 'weekly', true)
                this.StepperRow('Daily steps', 'steps', false)
              }
              .padding({ left: 14, right: 14 })
            }

            SectionLabel({ text: 'Workout' })
            Tile({ pad: 6 }) {
              Column() {
                this.ToggleRow('Haptics', 'A tick for each rep, a buzz to rack it', 'haptics', true)
                this.ToggleRow('Rest-over alerts', 'Buzz and notify when rest is over', 'restAlerts', true)
                this.ToggleRow('Reduce motion', AppModel.get().softwareRenderer() ?
                  'On by default here: this device renders in software' : 'Fewer animations; the creature still moves',
                  'motion', false)
              }
              .padding({ left: 14, right: 14 })
            }

            SectionLabel({ text: 'Demo' })
            Tile({ pad: 6 }) {
              Column() {
                this.ToggleRow('Demo mode', 'Simulated motion and steps, for emulators', 'demo', true)
                NavRow({
                  icon: $r('app.media.ic_flask'),
                  title: 'Load sample history',
                  divider: false,
                  onTap: () => this.ask('sample')
                })
              }
              .padding({ left: 14, right: 14 })
            }

            SectionLabel({ text: 'About' })
            Tile({ pad: 6 }) {
              Column() {
                NavRow({
                  icon: $r('app.media.ic_refresh'),
                  title: 'Replay introduction',
                  onTap: () => {
                    const params = new RouteParams();
                    params.replay = true;
                    navPush(this.getUIContext(), 'pages/Onboarding', params);
                  }
                })
                NavRow({
                  icon: $r('app.media.ic_shield'),
                  title: 'Privacy',
                  value: 'On-device only',
                  chevron: false,
                  onTap: () => this.toast('No account, no cloud, no network permission.')
                })
                NavRow({ icon: $r('app.media.ic_help'), title: 'Version', value: APP_VERSION, chevron: false, divider: false,
                  tappable: false })
              }
              .padding({ left: 14, right: 14 })
            }

            SectionLabel({ text: 'Data' })
            Tile({ pad: 6 }) {
              Column() {
                NavRow({
                  icon: $r('app.media.ic_trash_danger'),
                  title: 'Erase all data',
                  danger: true,
                  divider: false,
                  onTap: () => this.ask('erase')
                })
              }
              .padding({ left: 14, right: 14 })
            }
          }
          Text('Wisp Gym gives no medical advice. Fatigue is a tempo proxy, not a measurement. ' +
            'Font: Nunito, SIL Open Font License.')
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
            .width('100%')
            .padding({ left: 4, right: 4 })
            .margin({ top: 16, bottom: 32 })
        }
        .padding({ left: PAD, right: PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
    .bindSheet($$this.showName, this.NameSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
