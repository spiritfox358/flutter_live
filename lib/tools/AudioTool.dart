import 'dart:typed_data';

class AudioTool {
  AudioTool._();

  /// 给原始 PCM 数据加上标准的 WAV 文件头，让 audioplayers 能够识别播放
  static Uint8List addWavHeader(Uint8List pcmBytes, int sampleRate) {
    int channels = 1; // 单声道
    int byteRate = sampleRate * channels * 2; // 16-bit = 2 bytes
    int totalDataLen = pcmBytes.length + 36;
    int bitrate = 16;

    var header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, totalDataLen, Endian.little);
    // WAVE fmt
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little); // block align
    header.setUint16(34, bitrate, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, pcmBytes.length, Endian.little);

    var wavBytes = BytesBuilder();
    wavBytes.add(header.buffer.asUint8List());
    wavBytes.add(pcmBytes);
    return wavBytes.toBytes();
  }
}