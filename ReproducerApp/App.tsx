import { memo, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

const ROWS = 30;
const DEPTH = 6;
const TASKS = 50;
const garbage: unknown[] = [];
const scheduler = (globalThis as any).nativeRuntimeScheduler;

const Nested = memo(function Nested({
  depth,
  label,
}: {
  depth: number;
  label: number;
}) {
  if (depth === 0) {
    return <Text>{label}</Text>;
  }
  return (
    <View style={styles.row}>
      <Nested depth={depth - 1} label={label} />
    </View>
  );
});

function App() {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    for (let task = 0; task < TASKS; task++) {
      scheduler.unstable_scheduleCallback(scheduler.unstable_NormalPriority, () => {
        garbage[(tick * TASKS + task) % 5000] = Array.from({ length: 100 }, (_, i) => ({ i, s: String(i) }));
      });
    }
    setTick(t => t + 1);
  }, [tick]);

  return (
    <View style={styles.container}>
      <Text>{tick}</Text>
      {Array.from({ length: ROWS }, (_, row) => (
        <View key={row} style={[styles.row, { marginLeft: (tick + row) % 3 }]}>
          <Nested depth={DEPTH} label={row} />
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 60,
  },
  row: {
    flexDirection: 'row',
  },
});

export default App;
