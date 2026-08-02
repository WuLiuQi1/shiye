import 'package:flutter_test/flutter_test.dart';
import 'package:reader/features/listening/application/text_to_speech_controller.dart';

void main() {
  test('speech chunks preserve all non-whitespace content', () {
    const text = '第一句。第二句！第三句？';
    final chunks = TextToSpeechController.splitForSpeech(text, maxLength: 5);
    expect(chunks.join(), text);
  });

  test('empty text produces no speech chunks', () {
    expect(TextToSpeechController.splitForSpeech(' \n '), isEmpty);
  });
}
