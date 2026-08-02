#!/usr/bin/env python3
"""Configure Flutter-generated hosts to accept supported local book files."""

from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ANDROID = '{http://schemas.android.com/apk/res/android}'
ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')


def configure_android() -> None:
    manifest_path = Path('android/app/src/main/AndroidManifest.xml')
    if not manifest_path.exists():
        return
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    application = root.find('application')
    if application is None:
        raise RuntimeError('Generated Android manifest has no application element.')
    activity = next(
        (item for item in application.findall('activity')
         if item.get(ANDROID + 'name') in {'.MainActivity', 'com.shiye.reader.MainActivity'}),
        None,
    )
    if activity is None:
        raise RuntimeError('Generated Android manifest has no MainActivity.')
    activity.set(ANDROID + 'launchMode', 'singleTask')
    queries = root.find('queries')
    if queries is None:
        queries = ET.SubElement(root, 'queries')
    tts_action = 'android.intent.action.TTS_SERVICE'
    if not any(
        action.get(ANDROID + 'name') == tts_action
        for intent in queries.findall('intent')
        for action in intent.findall('action')
    ):
        intent = ET.SubElement(queries, 'intent')
        ET.SubElement(intent, 'action', {ANDROID + 'name': tts_action})
    marker = 'com.shiye.reader.BOOK_IMPORT'
    if any(item.get(ANDROID + 'name') == marker for item in activity.findall('meta-data')):
        tree.write(manifest_path, encoding='utf-8', xml_declaration=True)
        return
    ET.SubElement(activity, 'meta-data', {ANDROID + 'name': marker, ANDROID + 'value': 'true'})
    for action in ('android.intent.action.SEND', 'android.intent.action.VIEW'):
        intent = ET.SubElement(activity, 'intent-filter')
        ET.SubElement(intent, 'action', {ANDROID + 'name': action})
        ET.SubElement(intent, 'category', {ANDROID + 'name': 'android.intent.category.DEFAULT'})
        if action.endswith('VIEW'):
            ET.SubElement(intent, 'category', {ANDROID + 'name': 'android.intent.category.BROWSABLE'})
            ET.SubElement(intent, 'data', {ANDROID + 'scheme': 'content'})
            ET.SubElement(intent, 'data', {ANDROID + 'scheme': 'file'})
        ET.SubElement(intent, 'data', {ANDROID + 'mimeType': '*/*'})
    tree.write(manifest_path, encoding='utf-8', xml_declaration=True)


def configure_ios() -> None:
    plist_path = Path('ios/Runner/Info.plist')
    if not plist_path.exists():
        return
    with plist_path.open('rb') as source:
        plist = plistlib.load(source)
    types = plist.setdefault('CFBundleDocumentTypes', [])
    if not any(item.get('CFBundleTypeName') == '拾页书籍' for item in types):
        types.append({
            'CFBundleTypeName': '拾页书籍',
            'CFBundleTypeRole': 'Editor',
            'LSHandlerRank': 'Alternate',
            'CFBundleTypeExtensions': ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3'],
            'LSItemContentTypes': [
                'public.plain-text', 'org.idpf.epub-container', 'com.adobe.pdf',
                'com.amazon.mobi8-ebook', 'com.amazon.azw3-ebook',
            ],
        })
    plist['LSSupportsOpeningDocumentsInPlace'] = False
    # System TTS is audio playback. Keep a listening session alive on iOS
    # while the device is locked or the app is not foregrounded.
    modes = plist.setdefault('UIBackgroundModes', [])
    if 'audio' not in modes:
        modes.append('audio')
    with plist_path.open('wb') as target:
        plistlib.dump(plist, target, sort_keys=False)


if __name__ == '__main__':
    configure_android()
    configure_ios()
