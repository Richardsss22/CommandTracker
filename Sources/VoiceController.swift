import AVFoundation
import Speech
import AppKit

class VoiceController: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))! 
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var restartTimer: Timer?
    public var isPaused = false
    private var isRestarting = false
    private var isActing = false
    
    override init() {
        super.init()
        speechRecognizer.delegate = self
    }
    
    func checkPermissionsAndStart() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Permissão para Speech Recognition confirmada.")
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if granted {
                        print("Permissão para o Microfone concedida. A iniciar o motor.")
                        DispatchQueue.main.async {
                            self.startListening()
                        }
                    } else {
                        print("Acesso ao microfone recusado.")
                    }
                }
            default:
                print("Permissão de Speech Recognition não concedida.")
            }
        }
    }
    
    func startListening() {
        if isPaused || isRestarting { return }
        isRestarting = true
        isActing = false
        // Garantir que a sessão anterior está limpa antes de reiniciar
        stopListening()
        isRestarting = false
        print("\n🎙 Em escuta StandBy contínua...")
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { fatalError("Não foi possível criar o request") }
            
            // Força o processamento EXCLUSIVAMENTE offline/local!
            recognitionRequest.requiresOnDeviceRecognition = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                var isFinal = false
                
                if let result = result {
                    isFinal = result.isFinal
                    let text = result.bestTranscription.formattedString
                    
                    print("🗣 [StandBy]: \(text)")
                    
                    if !self.isActing {
                        if ActionHandler.shared.processContinuousCommand(text) {
                            self.isActing = true
                            self.recognitionRequest?.endAudio()
                        }
                    }
                    
                    if isFinal {
                        DispatchQueue.main.async {
                            self.startListening()
                        }
                    }
                }
                
                if error != nil {
                    self.stopListening()
                    if !self.isPaused && !isFinal {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.startListening()
                        }
                    }
                }
            }
            
            // Apple SFSpeechRecognizer tem limite de 60s p/ buffer ativo. 
            // Reinicia a cada 55s forçosamente para nunca emudecer.
            restartTimer = Timer.scheduledTimer(withTimeInterval: 55.0, repeats: false) { [weak self] _ in
                self?.recognitionRequest?.endAudio()
            }
            
        } catch {
            print("Erro no start do AVAudioEngine: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        restartTimer?.invalidate()
        restartTimer = nil
    }
}
