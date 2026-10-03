import { UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { F_BOLD, F_REG } from './Theme';

let done = false;

// Registers the bundled Nunito weights (SIL OFL, see rawfile/fonts/OFL.txt). Safe to call
// from every page; falls back to the system font if registration fails.
export function registerFonts(ui: UIContext): void {
  if (done) {
    return;
  }
  try {
    const f = ui.getFont();
    f.registerFont({ familyName: F_REG, familySrc: $rawfile('fonts/Nunito-Medium.ttf') });
    f.registerFont({ familyName: F_BOLD, familySrc: $rawfile('fonts/Nunito-ExtraBold.ttf') });
    done = true;
  } catch (e) {
    hilog.warn(0x0020, 'WispFonts', 'font registration failed: %{public}s', JSON.stringify(e));
  }
}
