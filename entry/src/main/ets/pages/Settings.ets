import { AppModel } from '../app/AppModel';
import { NAME_MAX, Profile, STEP_GOAL_MAX, STEP_GOAL_MIN, WEEKLY_GOAL_MAX, WEEKLY_GOAL_MIN, sanitizeName } from '../core/Profile';
import { formatSteps } from '../core/Plan';
import { Button56, IconButton, NavRow, SectionLabel, Tile } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { RouteParams } from '../ui/Nav';
import { ACCENT, BG, F_BOLD, F_REG, HAIRLINE, PAD, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE } from '../ui/Theme';

const APP_VERSION = '1.1.0';

@Entry
@Component
struct Settings {
  @State profile: Profile = new Profile();
  @State demo: boolean = false;
  @State workouts: number = 0;
  @State showName: boolean = false;
  @State draftName: string = '';
  @State confirm: string = '';          // '' | 'sample' | 'erase'
  @State showConfirm: boolean = false;

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
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
      this.toast('Loaded 14 days of simulated history');
    } else if (this.confirm === 'erase') {
      m.resetAll();
      this.showConfirm = false;
      router.clear();
      router.replaceUrl({ url: 'pages/Onboarding' });
      return;
    }
    this.showConfirm = false;
    this.load();
  }

  private isOn(key: string): boolean {
    if (key === 'haptics') {
      return this.profile.haptics;
    }
    if (key === 'restAlerts') {
      return this.profile.restAlerts;
    }
    return this.demo;
  }

  private toggle(key: string, v: boolean): void {
    if (key === 'demo') {
      AppModel.get().setDemo(v);
      this.load();
      this.toast(v ? 'Demo mode on: sensors are simulated' : 'Demo mode off: real sensors');
      return;
    }
    const p = this.profile;
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
        Text(title).fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
        IconButton({ icon: $r('app.media.ic_minus'), label: 'Decrease ' + title, diameter: 36, onTap: () => {
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
          .width(56)
          .textAlign(TextAlign.Center)
        IconButton({ icon: $r('app.media.ic_plus'), label: 'Increase ' + title, diameter: 36, onTap: () => {
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
        .defaultFocus(true)
        .enterKeyType(EnterKeyType.Done)
        .onChange((v: string) => {
          this.draftName = v;
        })
        .onSubmit(() => this.saveName())
      Button56({ label: 'Save', active: this.draftName.trim().length > 0, onTap: () => this.saveName() })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 16 })
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
      Text(this.confirm === 'erase' ? 'Erase all data?' : 'Replace history with sample data?')
        .fontSize(22)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
      Text(this.confirm === 'erase' ?
        'All workouts, your creature and your settings are deleted from this phone. This cannot be undone.' :
        'Your ' + this.workouts + (this.workouts === 1 ? ' workout is' : ' workouts are') +
          ' replaced by 14 days of clearly labelled simulated training, and Demo mode is turned on.')
        .fontSize(14)
        .fontFamily(F_REG)
        .fontColor(TEXT_DIM)
        .width('100%')
        .margin({ bottom: 8 })
      Button56({
        label: this.confirm === 'erase' ? 'Erase everything' : 'Load sample data',
        kind: this.confirm === 'erase' ? 'danger' : 'primary',
        onTap: () => this.runConfirm()
      })
      Button56({ label: 'Cancel', kind: 'ghost', onTap: () => {
        this.showConfirm = false;
      } })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 16 })
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
        height: 320,
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
                divider: false,
                onTap: () => {
                  this.draftName = this.profile.name;
                  this.showName = true;
                }
              })
            }
            .padding({ left: 14, right: 14 })
          }

          SectionLabel({ text: 'Goals' })
          Tile({ pad: 6 }) {
            Column() {
              this.StepperRow('Sessions per week', 'weekly', true)
              this.StepperRow('Daily steps', 'steps', false)
            }
            .padding({ left: 14, right: 14 })
          }

          SectionLabel({ text: 'Workout' })
          Tile({ pad: 6 }) {
            Column() {
              this.ToggleRow('Haptics', 'A tick for each rep, a buzz to rack it', 'haptics', true)
              this.ToggleRow('Rest-over alerts', 'Buzz and notify when rest is over', 'restAlerts', false)
            }
            .padding({ left: 14, right: 14 })
          }

          SectionLabel({ text: 'Demo' })
          Tile({ pad: 6 }) {
            Column() {
              this.ToggleRow('Demo mode', 'Simulated motion and steps, for emulators', 'demo', true)
              NavRow({
                icon: $r('app.media.ic_flask'),
                title: 'Load 2-week sample history',
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
                  this.getUIContext().getRouter().pushUrl({ url: 'pages/Onboarding', params: params });
                }
              })
              NavRow({
                icon: $r('app.media.ic_shield'),
                title: 'Privacy',
                value: 'On-device only',
                chevron: false,
                onTap: () => this.toast('No account, no cloud, no network permission.')
              })
              NavRow({ icon: $r('app.media.ic_help'), title: 'Version', value: APP_VERSION, chevron: false, divider: false })
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
      height: 260,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
