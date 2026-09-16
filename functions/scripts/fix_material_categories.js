/**
 * One-off: align materials.category with categories.name catalog.
 * Usage: node scripts/fix_material_categories.js [--dry-run]
 */
const path = require('path');
const os = require('os');
const admin = require('firebase-admin');

const dryRun = process.argv.includes('--dry-run');
const PROJECT_ID = 'ratebridge-2cd72';

async function initAdminWithFirebaseCliAuth() {
  const toolsRoot = path.join(
    os.homedir(),
    'AppData',
    'Roaming',
    'npm',
    'node_modules',
    'firebase-tools',
  );
  const auth = require(path.join(toolsRoot, 'lib', 'auth.js'));
  const scopes = require(path.join(toolsRoot, 'lib', 'scopes.js'));

  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Firebase CLI is not logged in. Run: firebase login');
  }

  const tokenResult = await auth.getAccessToken(account.tokens.refresh_token, [
    scopes.CLOUD_PLATFORM,
    scopes.FIREBASE_PLATFORM,
  ]);
  const accessToken =
    tokenResult?.access_token || tokenResult?.tokens?.access_token;
  if (!accessToken) {
    throw new Error('Failed to obtain Firebase access token.');
  }

  admin.initializeApp({
    projectId: PROJECT_ID,
    credential: {
      getAccessToken: async () => ({
        access_token: accessToken,
        expires_in: 3600,
      }),
    },
  });
}

function normalize(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

/** Map legacy / short labels onto current catalog names. */
function buildResolver(catalogNames) {
  const byExact = new Map(
    catalogNames.map((name) => [normalize(name), name]),
  );

  const aliases = {
    steel: 'Steel / TMT Bars',
    'tmt bars': 'Steel / TMT Bars',
    'tmt steel': 'Steel / TMT Bars',
    'steel bars': 'Steel / TMT Bars',
    timber: 'Timber / Wood',
    wood: 'Timber / Wood',
    crush: 'Crush / Aggregate',
    aggregate: 'Crush / Aggregate',
    aggregates: 'Crush / Aggregate',
    pipes: 'Pipes (PVC/GI)',
    pipe: 'Pipes (PVC/GI)',
    pvc: 'Pipes (PVC/GI)',
    sanitary: 'Sanitary Ware',
    electrical: 'Electrical Wire & Cable',
    wire: 'Electrical Wire & Cable',
    cable: 'Electrical Wire & Cable',
  };

  return (rawCategory) => {
    const key = normalize(rawCategory);
    if (!key) return null;
    if (byExact.has(key)) return byExact.get(key);

    if (aliases[key] && byExact.has(normalize(aliases[key]))) {
      return aliases[key];
    }

    const candidates = catalogNames.filter((name) => {
      const n = normalize(name);
      return (
        n === key ||
        n.startsWith(`${key} `) ||
        n.startsWith(`${key}/`) ||
        n.startsWith(`${key} /`) ||
        n.includes(` ${key} `) ||
        n.includes(`/${key}`)
      );
    });

    if (candidates.length === 1) return candidates[0];

    const starts = candidates.filter((name) =>
      normalize(name).startsWith(key),
    );
    if (starts.length === 1) return starts[0];

    return null;
  };
}

async function main() {
  await initAdminWithFirebaseCliAuth();
  const db = admin.firestore();

  const categoriesSnap = await db.collection('categories').get();
  const catalogNames = [
    ...new Set(
      categoriesSnap.docs
        .map((doc) => String(doc.data().name || '').trim())
        .filter((name) => name.length > 0),
    ),
  ];

  if (catalogNames.length === 0) {
    console.error('No categories found in Firestore.');
    process.exit(1);
  }

  console.log('Catalog category names:');
  for (const name of [...catalogNames].sort()) {
    console.log(`  - ${name}`);
  }

  const resolve = buildResolver(catalogNames);
  const materialsSnap = await db.collection('materials').get();

  const mismatches = [];
  const unmapped = [];
  let alreadyOk = 0;

  for (const doc of materialsSnap.docs) {
    const data = doc.data() || {};
    const current = String(data.category ?? '').trim();
    const exactMatch = catalogNames.includes(current);

    if (exactMatch) {
      alreadyOk += 1;
      continue;
    }

    const mapped = resolve(current);
    if (!mapped || mapped === current) {
      unmapped.push({
        id: doc.id,
        category: current,
        name: data.name,
      });
      continue;
    }

    mismatches.push({
      id: doc.id,
      name: data.name,
      from: current,
      to: mapped,
      ref: doc.ref,
    });
  }

  console.log(`\nMaterials total: ${materialsSnap.size}`);
  console.log(`Already matching catalog: ${alreadyOk}`);
  console.log(`To update: ${mismatches.length}`);
  console.log(`Unmapped (no safe target): ${unmapped.length}`);

  if (mismatches.length) {
    console.log('\nUpdates:');
    for (const row of mismatches) {
      console.log(
        `  ${row.id} | "${row.name}" | "${row.from}" -> "${row.to}"`,
      );
    }
  }

  if (unmapped.length) {
    console.log('\nUnmapped (left unchanged):');
    for (const row of unmapped) {
      console.log(
        `  ${row.id} | "${row.name}" | category="${row.category}"`,
      );
    }
  }

  if (dryRun) {
    console.log('\nDry run only — no writes.');
    process.exit(0);
  }

  if (mismatches.length === 0) {
    console.log('\nNothing to update.');
    process.exit(0);
  }

  const batchSize = 400;
  let updated = 0;
  for (let i = 0; i < mismatches.length; i += batchSize) {
    const chunk = mismatches.slice(i, i + batchSize);
    const batch = db.batch();
    for (const row of chunk) {
      batch.update(row.ref, { category: row.to });
    }
    await batch.commit();
    updated += chunk.length;
  }

  console.log(`\nUpdated ${updated} material document(s).`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
