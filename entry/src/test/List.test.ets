import localUnitTest from './LocalUnit.test';
import coreTest from './Core.test';

export default function testsuite() {
  localUnitTest();
  coreTest();
}
