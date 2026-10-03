import { AppModel } from '../app/AppModel';
import { LifeEngine, LifeConfig, CreatureState } from '../core/LifeEngine';
import { CreatureLook, lookFor } from '../core/CreatureLook';
import { WorkoutRecord } from '../core/Types';
import { generateHistory } from '../core/Sim';
import { CreatureCanvas } from '../components/CreatureCanvas';

@Entry
@Component
struct Week {
  @State look: CreatureLook = new CreatureLook();
  @State label: string = '';
  @State playing: boolean = false;
  @State summary: string[] = [];
  private timer: number = -1;
  private engine: LifeEngine = new LifeEngine(new LifeConfig());

  aboutToAppear(): void {
    const model = AppModel.get();
    const st = model.evaluateNow();
    this.look = model.lookFor(st);
    const ws = model.workouts();
    const lines: string[] = [];
    for (let i = Math.max(0, ws.length - 8); i < ws.length; i++) {
      const w = ws[i];
      let reps = 0;
      for (let s = 0; s < w.sets.length; s++) {
        reps += w.sets[s].reps;
      }
      const d = new Date(w.endMs);
      lines.push((d.getMonth() + 1) + '/' + d.getDate() + '  ' + w.sets.length + ' sets, ' + reps + ' reps' + (w.simulated ? '  (simulated)' : ''));
    }
    this.summary = lines.reverse();
  }

  aboutToDisappear(): void {
    this.stopTimeLapse();
  }

  private stopTimeLapse(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.playing = false;
  }

  private playTimeLapse(): void {
    if (this.playing) {
      return;
    }
    // A simulated 14-day journey: clearly labelled, independent of the user's real data.
    const now = Date.now();
    const all: WorkoutRecord[] = generateHistory(now, 14, 20261003);
    const seed = AppModel.get().seed();
    let day = 14;
    this.playing = true;
    this.timer = setInterval(() => {
      const t = now - (day - 1) * 86400000;
      const upTo: WorkoutRecord[] = all.filter((w: WorkoutRecord) => w.endMs <= t);
      const st: CreatureState = this.engine.evaluate(t, upTo, 5200);
      this.look = lookFor(st, seed);
      this.label = 'SIMULATED time-lapse, day ' + (15 - day) + ' of 14: ' + st.headline;
      day--;
      if (day < 1) {
        this.stopTimeLapse();
      }
    }, 1200);
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button('Back')
            .fontSize(13)
            .height(34)
            .backgroundColor('#2A2C5A')
            .onClick(() => this.getUIContext().getRouter().back())
          Text('My week')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E8EAF6')
            .margin({ left: 12 })
        }
        .width('100%')
        .margin({ top: 16, bottom: 8 })

        CreatureCanvas({ look: this.look, label: this.label })

        Button(this.playing ? 'Playing...' : 'Play 14-day evolution (simulated)')
          .width('100%')
          .height(46)
          .backgroundColor('#7E57C2')
          .enabled(!this.playing)
          .onClick(() => this.playTimeLapse())

        Text('Recent sessions')
          .fontSize(15)
          .fontColor('#C5CAE9')
          .width('100%')
          .margin({ top: 18, bottom: 8 })
        if (this.summary.length === 0) {
          Text('No sessions yet. Finish a workout or load the demo history on the home screen.')
            .fontSize(12)
            .fontColor('#9FA8DA')
            .width('100%')
        }
        ForEach(this.summary, (line: string) => {
          Text(line)
            .fontSize(13)
            .fontColor('#E8EAF6')
            .width('100%')
            .padding(12)
            .margin({ bottom: 6 })
            .borderRadius(10)
            .backgroundColor('#1F2147')
        }, (line: string) => line)
      }
      .padding({ left: 16, right: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#14152E')
    .scrollBar(BarState.Off)
  }
}
