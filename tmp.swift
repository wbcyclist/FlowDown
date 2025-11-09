import AVFAudio
import AVFoundation

func test(file: AVAudioFile, buffer: AVAudioCompressedBuffer) throws {
    try file.write(from: buffer)
}
