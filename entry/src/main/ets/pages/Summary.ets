import { AppModel } from '../app/AppModel';
import { CreatureState } from '../core/LifeEngine';
import { ExerciseLine, GroupGain, WorkoutSummary, formatDuration, joinAnd, plural } from '../core/Plan';
import { groupThousands } from '../core/Types';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { Button56, InfoRow, Reveal, SectionLabel, Tag, Tile } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import {
  ACCENT, BG, F_BOLD, F_REG, GAP, PAD, STAGGER, TEXT, TEXT_DIM, TEXT_MUTE, TRACK, ACCENT_SOFT
} from '../ui/Theme';
import { anim, pageDur } from '../ui/Motion';

// End-of-workout celebration: the creature reacts first, then the numbers, then what grew.
@Entry
@Component
struct Summary {
  @State summary: WorkoutSummary = new WorkoutSummary();
  @State name: string = 'Wisp';
  @State grown: boolean = false;
  private holder: LookHolder = new LookHolder();

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    const model = AppModel.get();
    const s = model.lastSummary();
    if (s === null) {
      // Nothing to celebrate (e.g. the page was restored without a workout): go back.
      setTimeout(() => this.getUIContext().getRouter().back(), 0);
    } else {
      this.summary = s;
    }
    this.name = model.profile().name;
    const st: CreatureState = model.evaluateNow();
    const look = model.lookFor(st);
    look.happyEyes = true;
    look.smile = 1;
    look.mood = 'proud';
    this.holder.set(look, true);
    setTimeout(() => {
      this.holder.poke();
      model.tick(40);
      this.grown = true;
    }, 450);
  }

  onPageShow(): void {
    this.holder.active = true;
  }

  onPageHide(): void {
    this.holder.active = false;
  }

  pageTransition() {
    PageTransitionEnter({ duration: pageDur(420), curve: Curve.Friction })
      .opacity(0)
      .scale({ x: 0.94, y: 0.94 })
    PageTransitionExit({ duration: pageDur(260), curve: Curve.EaseIn })
      .opacity(0)
  }

  private done(): void {
    this.getUIContext().getRouter().back();
  }

  private unlockText(): string {
    const parts: string[] = [];
    if (this.summary.newSpecies.length > 0) {
      parts.push(this.summary.newSpecies.join(', ') + ' joined your collection.');
    }
    if (this.summary.newBadges.length > 0) {
      parts.push((this.summary.newBadges.length === 1 ? 'Badge: ' : 'Badges: ') + this.summary.newBadges.join(', ') + '.');
    }
    return parts.join(' ');
  }

  private headline(): string {
    if (this.summary.gains.length === 0) {
      return 'Workout saved';
    }
    const names = this.summary.gains.map((g: GroupGain) => g.label.toLowerCase());
    return this.name + ' grew: ' + joinAnd(names);
  }

  @Builder
  Big(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(28)
        .maxFontSize(28)
        .minFontSize(15)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label).fontSize(12).fontFamily(F_REG).fontColor(TEXT_MUTE)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  GainRow(g: GroupGain, i: number) {
    Column({ space: 8 }) {
      Row() {
        Text(g.label).fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
        Text(Math.round(g.before * 100) + '%  →  ').fontSize(14).fontFamily(F_REG).fontColor(TEXT_MUTE)
        Text(Math.round(g.after * 100) + '%').fontSize(15).fontFamily(F_BOLD).fontColor(ACCENT)
      }
      .width('100%')
      Stack({ alignContent: Alignment.Start }) {
        Column().width('100%').height(8).borderRadius(4).backgroundColor(TRACK)
        Column()
          .width((Math.max(0.02, this.grown ? g.after : g.before) * 100).toFixed(1) + '%')
          .height(8)
          .borderRadius(4)
          .backgroundColor(ACCENT)
          .animation(anim({ duration: 900, delay: 500 + i * 150, curve: Curve.Friction }))
        Column()
          .width((Math.max(0.02, g.before) * 100).toFixed(1) + '%')
          .height(8)
          .borderRadius(4)
          .backgroundColor(TEXT)
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: GAP }) {
          Reveal({ delay: 0 }) {
            Column() {
              CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 220, tappable: true })
              Row({ space: 8 }) {
                Text('Great session').fontSize(28).fontFamily(F_BOLD).fontColor(TEXT)
                if (this.summary.simulated) {
                  Tag({ text: 'DEMO', accent: true })
                }
              }
              .margin({ top: 4 })
              Text(this.headline())
                .fontSize(15)
                .fontFamily(F_REG)
                .fontColor(TEXT_DIM)
                .margin({ top: 4 })
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .margin({ top: 16 })
          }

          Reveal({ delay: STAGGER * 2 }) {
            Tile({ pad: 20 }) {
              Row({ space: 8 }) {
                this.Big(formatDuration(this.summary.durationMs), 'duration')
                this.Big('' + this.summary.sets, this.summary.sets === 1 ? 'set' : 'sets')
                this.Big('' + this.summary.reps, 'reps = XP')
              }
              .width('100%')
              if (this.summary.volumeKg > 0) {
                Text('Volume lifted: ' + groupThousands(Math.round(this.summary.volumeKg)) + ' kg')
                  .fontSize(13)
                  .fontFamily(F_BOLD)
                  .fontColor(TEXT_DIM)
                  .width('100%')
                  .margin({ top: 14 })
              }
              if (this.summary.cues > 0) {
                Text(this.summary.cues + (this.summary.cues === 1 ? ' set' : ' sets') +
                  ' reached the "rack it" point. That is quality work, not failure.')
                  .fontSize(12)
                  .fontFamily(F_REG)
                  .fontColor(TEXT_MUTE)
                  .width('100%')
                  .margin({ top: 14 })
              }
            }
          }

          if (this.summary.levelAfter > this.summary.levelBefore) {
            Reveal({ delay: STAGGER }) {
              Tile({ pad: 18, highlight: true }) {
                Row() {
                  Column({ space: 3 }) {
                    Text('Level up!').fontSize(17).fontFamily(F_BOLD).fontColor(TEXT)
                    Text(this.name + ' reached level ' + this.summary.levelAfter + '. Every rep is experience.')
                      .fontSize(13)
                      .fontFamily(F_REG)
                      .fontColor(TEXT_DIM)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Text('Lv ' + this.summary.levelAfter).fontSize(26).fontFamily(F_BOLD).fontColor(ACCENT)
                }
                .width('100%')
              }
            }
          }

          if (this.summary.prs.length > 0) {
            Reveal({ delay: STAGGER * 2 }) {
              Tile({ pad: 18, highlight: true }) {
                Row({ space: 14 }) {
                  Image($r('app.media.ic_bolt_accent'))
                    .width(44)
                    .height(44)
                    .padding(11)
                    .borderRadius(22)
                    .backgroundColor(ACCENT_SOFT)
                  Column({ space: 3 }) {
                    Text(this.summary.prs.length === 1 ? 'New personal record!' : 'New personal records!')
                      .fontSize(17)
                      .fontFamily(F_BOLD)
                      .fontColor(TEXT)
                    Text('Heaviest ever: ' + joinAnd(this.summary.prs) + '.')
                      .fontSize(13)
                      .fontFamily(F_REG)
                      .fontColor(TEXT_DIM)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
            }
          }

          if (this.summary.newSpecies.length > 0 || this.summary.newBadges.length > 0) {
            Reveal({ delay: STAGGER * 2 }) {
              Tile({ pad: 18, highlight: true }) {
                Row({ space: 14 }) {
                  Image($r('app.media.ic_trophy_accent'))
                    .width(44)
                    .height(44)
                    .padding(11)
                    .borderRadius(22)
                    .backgroundColor(ACCENT_SOFT)
                  Column({ space: 3 }) {
                    Text(this.summary.newSpecies.length > 0 ? 'New creature hatched!' : 'New badge earned!')
                      .fontSize(17)
                      .fontFamily(F_BOLD)
                      .fontColor(TEXT)
                    Text(this.unlockText())
                      .fontSize(13)
                      .fontFamily(F_REG)
                      .fontColor(TEXT_DIM)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
            }
          }

          if (this.summary.gains.length > 0) {
            SectionLabel({ text: 'What grew' })
            Reveal({ delay: STAGGER * 3 }) {
              Tile({ pad: 20 }) {
                Column({ space: 18 }) {
                  ForEach(this.summary.gains, (g: GroupGain, i: number) => {
                    this.GainRow(g, i)
                  }, (g: GroupGain) => g.group)
                }
                .width('100%')
              }
            }
          }

          SectionLabel({ text: 'Exercises' })
          Reveal({ delay: STAGGER * 4 }) {
            Tile({ pad: 20 }) {
              ForEach(this.summary.exercises, (e: ExerciseLine, i: number) => {
                InfoRow({
                  label: e.name,
                  value: plural(e.reps, 'rep'),
                  sub: plural(e.sets, 'set'),
                  divider: i < this.summary.exercises.length - 1
                })
              }, (e: ExerciseLine) => e.name)
            }
          }
          Blank().height(16)
        }
        .padding({ left: PAD, right: PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column() {
        Button56({ label: 'Done', onTap: () => this.done() })
      }
      .padding({ left: PAD, right: PAD, top: 8, bottom: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
