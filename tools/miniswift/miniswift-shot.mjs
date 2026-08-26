#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const STUDIO_URL = 'https://miniswift.run/studio/';

function arg(name, fallback = undefined) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : fallback;
}

const sourcePath = arg('source');
const outputPath = arg('output', './artifacts/miniswift-phone.png');
const editorSelector = arg('editor-selector');
const runSelector = arg('run-selector');
const previewSelector = arg('preview-selector');
const timeoutMs = Number(arg('timeout-ms', '30000'));

if (!sourcePath) {
  console.error('Usage: miniswift-shot.mjs --source FILE [--output FILE] [--preview-selector SELECTOR]');
  process.exit(2);
}

const source = await fs.readFile(sourcePath, 'utf8');
await fs.mkdir(path.dirname(outputPath), { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1100 }, deviceScaleFactor: 1 });

async function diagnostics(error) {
  const diagnosticPath = outputPath.replace(/\.(png|jpg|jpeg|webp)$/i, '.diagnostic.png');
  await page.screenshot({ path: diagnosticPath, fullPage: true });
  console.error(`MiniSwift verification failed: ${error instanceof Error ? error.message : error}`);
  console.error(`Diagnostic screenshot: ${diagnosticPath}`);
}

function parseTextNodes() {
  return page.locator('body *').filter({ hasText: /Run|Compile|Build/i });
}

try {
  await page.goto(STUDIO_URL, { waitUntil: 'domcontentloaded', timeout: timeoutMs });

  if (editorSelector) {
    await page.locator(editorSelector).fill(source);
  } else {
    const editors = [
      page.locator('textarea').first(),
      page.locator('[contenteditable="true"]').first(),
      page.locator('[role="textbox"]').first(),
    ];
    let filled = false;
    for (const editor of editors) {
      if (await editor.count()) {
        try {
          await editor.fill(source);
          filled = true;
          break;
        } catch {}
      }
    }
    if (!filled) throw new Error('No editable Swift source control found. Supply --editor-selector.');
  }

  if (runSelector) {
    await page.locator(runSelector).click();
  } else {
    const candidates = [
      page.getByRole('button', { name: /^Run$/i }).first(),
      page.getByRole('button', { name: /Run|Compile/i }).first(),
      page.locator('button').filter({ hasText: /Run|Compile/i }).first(),
    ];
    let clicked = false;
    for (const candidate of candidates) {
      if (await candidate.count()) {
        try {
          await candidate.click();
          clicked = true;
          break;
        } catch {}
      }
    }
    if (!clicked) throw new Error('No Run/Compile button found. Supply --run-selector.');
  }

  if (previewSelector) {
    const preview = page.locator(previewSelector).first();
    await preview.waitFor({ state: 'visible', timeout: timeoutMs });
    await preview.screenshot({ path: outputPath });
  } else {
    const phoneHints = [
      '[data-phone]',
      '[data-preview]',
      '[aria-label*="preview" i]',
      '[class*="phone" i]',
      '[class*="device" i]',
      'canvas',
    ];

    let captured = false;
    for (const selector of phoneHints) {
      const matches = page.locator(selector);
      const count = await matches.count();
      for (let i = 0; i < count; i += 1) {
        const node = matches.nth(i);
        if (!(await node.isVisible().catch(() => false))) continue;
        const box = await node.boundingBox().catch(() => null);
        if (!box) continue;
        const ratio = box.height / Math.max(box.width, 1);
        if (box.width >= 180 && box.height >= 300 && ratio >= 1.2 && ratio <= 2.4) {
          await node.screenshot({ path: outputPath });
          captured = true;
          break;
        }
      }
      if (captured) break;
    }

    if (!captured) {
      throw new Error('Could not identify the phone preview. Supply --preview-selector.');
    }
  }

  console.log(`MiniSwift phone preview saved to ${outputPath}`);
} catch (error) {
  await diagnostics(error);
  process.exitCode = 1;
} finally {
  await browser.close();
}
