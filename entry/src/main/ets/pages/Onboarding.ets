import { AppModel } from '../app/AppModel';
import { CreatureLook } from '../core/CreatureLook';
import { NAME_MAX, Profile, sanitizeName } from '../core/Profile';
import { formatSteps } from '../core/Plan';
import { SPECIES, Species, findSpecies } from '../core/Species';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { Button56, Chip, IconButton } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { RouteParams, navReplace } from '../ui/Nav';
import {
  ACCENT, ACCENT_TINT, BG, DUR_MED, F_BOLD, F_REG, HAIRLINE, PAD, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE, TRACK, ACCENT_BORDER
} from '../ui/Theme';
import { anim, fx, press } from '../ui/Motion';

const STEP_FX: TransitionEffect = TransitionEffect.asymmetric(
  TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 36 })),
  TransitionEffect.OPACITY
);
// Name ideas besides the species' own name (never another species' name).
const NAMES: string[] = ['Bao', 'Tofu', 'Kiki', 'Bean', 'Nori'];
const STARTERS: Species[] = SPECIES.filter((s: Species) => s.unlock.length === 0);
const LATER: Species[] = SPECIES.filter((s: Species) => s.unlock.length > 0);

// Sleeping preview of a creature that hatches later.
function sleeper(sp: Species): LookHolder {
  const h = new LookHolder();
  const look = new CreatureLook();
  look.species = sp.id;
  look.hue = sp.hueBase;
  look.expression = 'asleep';
  h.set(look, true);
  return h;
}
const SLEEPERS: LookHolder[] = LATER.map((sp: Species) => sleeper(sp));
const WEEKLY: number[] = [2, 3, 4, 5];
const STEP_GOALS: number[] = [6000, 8000, 10000, 12000];

class Feature {
  icon: Resource;
  title: string;
  body: string;

  constructor(icon: Resource, title: string, body: string) {
    this.icon = icon;
    this.title = title;
    this.body = body;
  }
}

// First-run introduction: bond with the creature first, then goals, then permissions,
// each behind its own explanation. Every choice can be changed later in Settings.
@Entry
@Component
struct Onboarding {
  @State step: number = 0;
  @State name: string = 'Wisp';
  @State species: string = 'wisp';
  @State weekly: number = 3;
  @State stepGoal: number = 8000;
  @State useDemo: boolean = false;
  @State replay: boolean = false;
  @State asking: boolean = false;
  private holder: LookHolder = new LookHolder();
  private steps: string[] = ['welcome', 'how', 'creature', 'name', 'goals', 'permissions', 'mode', 'ready'];

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    const params = this.getUIContext().getRouter().getParams() as RouteParams;
    this.replay = params !== undefined && params !== null && params.replay === true;
    if (this.replay) {
      // A replay keeps the user's data; choosing demo data here would overwrite it.
      this.steps = ['welcome', 'how', 'creature', 'name', 'goals', 'permissions', 'ready'];
      const p = AppModel.get().profile();
      this.name = p.name;
      this.species = p.species;
      this.weekly = p.weeklyGoal;
      this.stepGoal = p.stepGoal;
    }
    const look = new CreatureLook();
    look.species = this.species;
    look.hue = findSpecies(this.species).hueBase;
    look.mood = 'curious';
    look.smile = 0.6;
    look.bob = 0.7;
    this.holder.set(look, true);
    setTimeout(() => this.holder.poke(), 700);
  }

  onPageShow(): void {
    this.holder.active = true;
  }

  onPageHide(): void {
    this.holder.active = false;
  }

  onBackPress(): boolean {
    if (this.step > 0) {
      this.go(this.step - 1);
      return true;
    }
    return false;
  }

  // Starter choice: the preview switches body and colours, and the suggested name follows
  // the species while the user has not typed their own.
  private pickSpecies(id: string): void {
    const prev = findSpecies(this.species);
    this.species = id;
    const sp = findSpecies(id);
    if (this.name === prev.name || this.name.trim().length === 0) {
      this.name = sp.name;
    }
    const look = this.holder.look;
    look.species = id;
    look.hue = sp.hueBase;
    this.holder.express('joy', 900);
    this.holder.poke();
    AppModel.get().tick(10);
  }

  private stepId(): string {
    return this.steps[this.step];
  }

  private go(next: number): void {
    const n = Math.max(0, Math.min(this.steps.length - 1, next));
    this.getUIContext().animateTo(anim({ duration: DUR_MED, curve: Curve.Friction }), () => {
      this.step = n;
    });
    const look = this.holder.look;
    if (this.steps[n] === 'ready') {
      look.mood = 'proud';
      look.happyEyes = true;
      look.smile = 1;
      look.glow = 0.9;
      look.bob = 1;
      setTimeout(() => this.holder.poke(), 500);
    } else {
      look.mood = 'curious';
      look.happyEyes = false;
      look.smile = 0.6;
    }
    AppModel.get().tick(8);
  }

  private async allowPermissions(): Promise<void> {
    if (this.asking) {
      return;
    }
    this.asking = true;
    const model = AppModel.get();
    try {
      await model.requestMotionPermission();
      const n = model.notifierOrNull();
      if (n !== null) {
        await n.ensureEnabled();
      }
    } finally {
      this.asking = false;
      this.go(this.step + 1);
    }
  }

  private finish(): void {
    const model = AppModel.get();
    const p: Profile = model.profile();
    p.name = sanitizeName(this.name);
    p.species = this.species;
    p.motionAsked = true; // the permissions step offered it (Allow or Not now)
    p.weeklyGoal = this.weekly;
    p.stepGoal = this.stepGoal;
    p.onboarded = true;
    model.saveProfile(p);
    const router = this.getUIContext().getRouter();
    if (this.replay) {
      router.back();
      return;
    }
    if (this.useDemo) {
      model.loadDemoHistory();
    } else {
      model.setDemo(false);
    }
    navReplace(this.getUIContext(), 'pages/Index');
  }

  private primaryLabel(): string {
    const id = this.stepId();
    if (id === 'welcome') {
      return 'Get started';
    }
    if (id === 'permissions') {
      return this.asking ? 'Waiting...' : 'Allow';
    }
    if (id === 'ready') {
      return this.replay ? 'Done' : 'Let\'s go';
    }
    return 'Continue';
  }

  private onPrimary(): void {
    const id = this.stepId();
    if (id === 'permissions') {
      this.allowPermissions();
    } else if (id === 'ready') {
      this.finish();
    } else {
      this.go(this.step + 1);
    }
  }

  // ---- Steps ------------------------------------------------------------------------

  @Builder
  Title(title: string, body: string) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(30)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
      if (body.length > 0) {
        Text(body)
          .fontSize(16)
          .fontFamily(F_REG)
          .fontColor(TEXT_DIM)
          .lineHeight(23)
          .width('100%')
      }
    }
  }

  @Builder
  FeatureRow(f: Feature) {
    Row({ space: 16 }) {
      Image(f.icon)
        .width(48)
        .height(48)
        .padding(12)
        .borderRadius(24)
        .backgroundColor(ACCENT_TINT)
      Column({ space: 3 }) {
        Text(f.title).fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
        Text(f.body).fontSize(14).fontFamily(F_REG).fontColor(TEXT_DIM).lineHeight(20).width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  ChoiceCard(title: string, body: string, demo: boolean, icon: Resource) {
    Row({ space: 14 }) {
      Image(icon).width(26).height(26)
      Column({ space: 3 }) {
        Text(title).fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
        Text(body).fontSize(13).fontFamily(F_REG).fontColor(TEXT_DIM).lineHeight(19).width('100%')
      }
      .layoutWeight(1)
      Stack() {
        if (this.useDemo === demo) {
          Circle().width(12).height(12).fill(ACCENT)
        }
      }
      .width(24)
      .height(24)
      .borderRadius(12)
      .border({ width: 2, color: this.useDemo === demo ? ACCENT : TEXT_MUTE })
    }
    .width('100%')
    .padding(18)
    .borderRadius(22)
    .backgroundColor(this.useDemo === demo ? ACCENT_TINT : SURFACE)
    .border({ width: 1, color: this.useDemo === demo ? ACCENT_BORDER : HAIRLINE })
    .animation(anim({ duration: 180, curve: Curve.EaseOut }))
    .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.97 }))
    .accessibilityText(title + (this.useDemo === demo ? ', selected' : ''))
    .onClick(() => {
      this.useDemo = demo;
      AppModel.get().tick(8);
    })
  }

  @Builder
  StepContent() {
    if (this.stepId() === 'welcome') {
      Column({ space: 8 }) {
        CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 290, tappable: true })
        this.Title(this.replay ? 'Meet ' + this.name + ' again' : 'Meet your training buddy',
          'A little creature that grows from your real training. Your phone counts the reps, you do the work.')
      }
      .transition(fx(STEP_FX))
    } else if (this.stepId() === 'how') {
      Column({ space: 28 }) {
        this.Title('How it works', '')
        this.FeatureRow(new Feature($r('app.media.ic_phone_accent'), 'Reps counted from motion',
          'Keep the phone in a pocket or armband. No wearable, no account.'))
        this.FeatureRow(new Feature($r('app.media.ic_bolt_accent'), 'Knows when to stop',
          'When your reps slow down you get a "rack it" cue, with the numbers behind it.'))
        this.FeatureRow(new Feature($r('app.media.ic_moon_accent'), 'Rest is part of the game',
          'Train hard and it asks for a rest day. It is never sad and there are no streaks to lose.'))
      }
      .padding({ top: 24 })
      .transition(fx(STEP_FX))
    } else if (this.stepId() === 'creature') {
      Column({ space: 14 }) {
        CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 200, tappable: true })
        this.Title('Choose your creature', 'Three starters to pick from. More hatch as you train.')
        Row({ space: 8 }) {
          ForEach(STARTERS, (sp: Species) => {
            Column({ space: 4 }) {
              Text(sp.name)
                .fontSize(15)
                .fontFamily(F_BOLD)
                .fontColor(this.species === sp.id ? ACCENT : TEXT)
            }
            .layoutWeight(1)
            .height(48)
            .justifyContent(FlexAlign.Center)
            .borderRadius(24)
            .backgroundColor(this.species === sp.id ? ACCENT_TINT : SURFACE_HI)
            .border({ width: 1, color: this.species === sp.id ? ACCENT_BORDER : HAIRLINE })
            .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.94 }))
            .accessibilityText(sp.name + (this.species === sp.id ? ', selected' : ''))
            .onClick(() => this.pickSpecies(sp.id))
          }, (sp: Species) => sp.id)
        }
        .width('100%')
        Text(findSpecies(this.species).blurb)
          .fontSize(14)
          .fontFamily(F_REG)
          .fontColor(TEXT_DIM)
          .width('100%')
          .lineHeight(20)
        Row({ space: 10 }) {
          ForEach(LATER, (sp: Species, i: number) => {
            Column() {
              CreatureCanvas({ holder: SLEEPERS[i], label: '', canvasHeight: 40, portrait: true, still: true,
                a11y: sp.name + ', hatches later' })
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(SURFACE_HI)
            .clip(true)
            .opacity(0.55)
          }, (sp: Species) => 'later-' + sp.id)
          Text(LATER.length + ' more hatch as you train')
            .fontSize(13)
            .fontFamily(F_BOLD)
            .fontColor(TEXT_MUTE)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .transition(fx(STEP_FX))
    } else if (this.stepId() === 'name') {
      Column({ space: 18 }) {
        CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 170, tappable: true })
        this.Title('Give it a name', 'You can change it any time.')
        TextInput({ text: this.name, placeholder: 'Name' })
          .maxLength(NAME_MAX)
          .height(56)
          .fontSize(20)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .placeholderColor(TEXT_MUTE)
          .caretColor(ACCENT)
          .backgroundColor(SURFACE_HI)
          .borderRadius(18)
          .padding({ left: 18, right: 18 })
          .enterKeyType(EnterKeyType.Done)
          .accessibilityText('Creature name')
          .onChange((v: string) => {
            this.name = v;
          })
          .onSubmit(() => {
            if (this.name.trim().length > 0) {
              this.go(this.step + 1);
            }
          })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach([findSpecies(this.species).name].concat(NAMES), (n: string) => {
            Chip({ text: n, selected: this.name === n, onTap: () => {
              this.name = n;
              this.holder.poke();
            } })
              .margin({ right: 8, bottom: 8 })
          }, (n: string) => n)
        }
        .width('100%')
      }
      .transition(fx(STEP_FX))
    } else if (this.stepId() === 'goals') {
      Column({ space: 24 }) {
        this.Title('Set a gentle goal', 'Small and steady wins. Rest days never break anything.')
        Column({ space: 10 }) {
          Text('Training sessions per week').fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
          Row({ space: 8 }) {
            ForEach(WEEKLY, (n: number) => {
              Chip({ text: '' + n, selected: this.weekly === n, grow: true, onTap: () => {
                this.weekly = n;
                AppModel.get().tick(8);
              } })
            }, (n: number) => 'w' + n)
          }
          .width('100%')
        }
        Column({ space: 10 }) {
          Text('Daily steps').fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
          Row({ space: 8 }) {
            ForEach(STEP_GOALS, (n: number) => {
              Chip({ text: formatSteps(n), selected: this.stepGoal === n, grow: true, onTap: () => {
                this.stepGoal = n;
                AppModel.get().tick(8);
              } })
            }, (n: number) => 's' + n)
          }
          .width('100%')
        }
        Text('You can change these any time in Settings.')
          .fontSize(13)
          .fontFamily(F_REG)
          .fontColor(TEXT_MUTE)
          .width('100%')
      }
      .padding({ top: 24 })
      .transition(fx(STEP_FX))
    } else if (this.stepId() === 'permissions') {
      Column({ space: 28 }) {
        this.Title('Two small permissions', 'Both are optional. Wisp Gym works without them.')
        this.FeatureRow(new Feature($r('app.media.ic_steps_accent'), 'Steps',
          sanitizeName(this.name) + ' glows brighter on days you move. Your step count never leaves this phone.'))
        this.FeatureRow(new Feature($r('app.media.ic_bell_accent'), 'Rest alerts',
          'A buzz and a notification when your rest between sets is over.'))
      }
      .padding({ top: 24 })
      .transition(fx(STEP_FX))
    } else if (this.stepId() === 'mode') {
      Column({ space: 14 }) {
        this.Title('How do you want to start?', '')
        this.ChoiceCard('Use my phone\'s sensors', 'Count real reps with the accelerometer.', false,
          $r('app.media.ic_phone'))
        this.ChoiceCard('Explore the demo', 'Simulated motion plus 14 days of sample training, clearly labelled. ' +
          'Ideal on an emulator.', true, $r('app.media.ic_flask'))
        Text('You can switch any time in Settings.')
          .fontSize(13)
          .fontFamily(F_REG)
          .fontColor(TEXT_MUTE)
          .width('100%')
          .margin({ top: 4 })
      }
      .padding({ top: 24 })
      .transition(fx(STEP_FX))
    } else {
      Column({ space: 8 }) {
        CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 290, tappable: true })
        this.Title('Say hi to ' + sanitizeName(this.name),
          'Your first set makes ' + sanitizeName(this.name) + ' grow. Tap it any time to say hi.')
      }
      .transition(fx(STEP_FX))
    }
  }

  build() {
    Column() {
      // Top bar: back, progress, skip
      Row({ space: 12 }) {
        if (this.step > 0) {
          IconButton({ icon: $r('app.media.ic_back'), label: 'Back', diameter: 40, onTap: () => this.go(this.step - 1) })
        } else {
          Blank().width(40).height(40)
        }
        Row({ space: 4 }) {
          ForEach(this.steps, (s: string, i: number) => {
            Column()
              .height(4)
              .layoutWeight(1)
              .borderRadius(2)
              .backgroundColor(i <= this.step ? ACCENT : TRACK)
              .animation(anim({ duration: DUR_MED, curve: Curve.Friction }))
          }, (s: string) => s)
        }
        .layoutWeight(1)
        if (this.step < 2) {
          Text('Skip')
            .fontSize(14)
            .fontFamily(F_BOLD)
            .fontColor(TEXT_DIM)
            .width(48)
            .height(40)
            .textAlign(TextAlign.End)
            .accessibilityText('Skip introduction')
            .onClick(() => this.go(2))
        } else {
          Blank().width(40)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: PAD, right: PAD })

      Scroll() {
        Column() {
          this.StepContent()
        }
        .width('100%')
        .padding({ left: PAD + 4, right: PAD + 4, top: 8, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Column({ space: 6 }) {
        Button56({
          label: this.primaryLabel(),
          active: !(this.stepId() === 'name' && this.name.trim().length === 0) && !this.asking,
          onTap: () => this.onPrimary()
        })
        if (this.stepId() === 'permissions') {
          Button56({ label: 'Not now', kind: 'ghost', height56: 48, onTap: () => this.go(this.step + 1) })
        }
      }
      .padding({ left: PAD, right: PAD, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
