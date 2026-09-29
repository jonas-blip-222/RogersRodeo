import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

// Prüfungen des OpenRouter-Adapters, die ohne Netz aussagekräftig sind: Aufbau des
// Anfragekörpers, Schema, Abbildung der Antwort auf Ergebnis oder Fehler, Schlüsselsuche.
// Bewusst kein Test, der die Schnittstelle wirklich aufruft — das kostet bei jedem Lauf Geld
// und hinge von der Verfügbarkeit der Gegenseite ab.

private func object(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

// MARK: - JSON-Baum

@Test func jsonValueSerialisiertNullOhneAbsturz() throws {
    // Der ursprüngliche Entwurf schrieb Swifts `nil` in ein `[Any]` und übergab das an
    // JSONSerialization. Das bricht zur Laufzeit ab. Hier muss echtes JSON-null herauskommen.
    let value = JSONValue.object(["enum": .array([.string("a"), .null]), "n": .int(3), "d": .double(0.5)])
    let text = try #require(String(data: try value.serialized(), encoding: .utf8))
    #expect(text == #"{"d":0.5,"enum":["a",null],"n":3}"#)
}

// MARK: - Schema

@Test func einordnungsschemaEnthaeltBelegteDoppelseitigeReflexion() throws {
    let schema = try object(try OpenRouterSchema.analysis.serialized())
    #expect(schema["additionalProperties"] as? Bool == false)
    #expect(schema["required"] as? [String] == ["segments", "doubleSidedReflection", "permissions", "characterObservations", "goalUpdates"])
    let properties = try #require(schema["properties"] as? [String: Any])
    let segments = try #require(properties["segments"] as? [String: Any])
    #expect(segments["type"] as? String == "array")
    let items = try #require(segments["items"] as? [String: Any])
    // Der strikte Modus verlangt jede Eigenschaft in `required`.
    let required = try #require(items["required"] as? [String])
    let fields = try #require(items["properties"] as? [String: Any])
    #expect(Set(required) == Set(fields.keys))
    #expect(Set(required) == ["quote", "code", "isUncertain", "supportingClientQuote"])
    let code = try #require(fields["code"] as? [String: Any])
    #expect(code["enum"] as? [String] == CounselorCode.allCases.map(\.rawValue))
    let support = try #require(fields["supportingClientQuote"] as? [String: Any])
    #expect(support["type"] as? [String] == ["string", "null"])
    // `maxItems` gehört nicht hinein: die gemessene Fassung kennt es nicht, und
    // OutputValidator.locations begrenzt ohnehin auf zwölf Segmente.
    #expect(segments["maxItems"] == nil)
}

@Test func antwortschemaErlaubtNullAlsHaltung() throws {
    let schema = try object(try OpenRouterSchema.reply.serialized())
    let fields = try #require((schema["properties"] as? [String: Any]))
    let tag = try #require(fields["primaryTag"] as? [String: Any])
    #expect(tag["type"] as? [String] == ["string", "null"])
    let values = try #require(tag["enum"] as? [Any])
    // Alle Haltungen plus echtes JSON-null. Ohne den Nullwert in der Aufzählung schlösse
    // das Schema ihn wieder aus, obwohl `type` ihn erlaubt.
    #expect(values.count == ClientTag.allCases.count + 1)
    #expect(values.compactMap { $0 as? String } == ClientTag.allCases.map(\.rawValue))
    #expect(values.last is NSNull)
    #expect(Set(try #require(schema["required"] as? [String])) == Set(fields.keys))
}

@Test func anfragekoerperEnthaeltAusschlusslisteUndUeberlegen() throws {
    var configuration = OpenRouterConfiguration()
    configuration.ignoredProviders = ["wafer", "mancer", "parasail"]
    let body = try object(try OpenRouterSchema.body(
        configuration: configuration, system: "S", user: "U",
        responseFormat: OpenRouterSchema.responseFormat(name: "ClientReply", schema: OpenRouterSchema.reply),
        temperature: 0.8, maxTokens: 2000, reasoning: false).serialized())
    #expect(body["model"] as? String == configuration.model)
    #expect(body["max_tokens"] as? Int == 2000)
    let provider = try #require(body["provider"] as? [String: Any])
    #expect(provider["ignore"] as? [String] == ["wafer", "mancer", "parasail"])
    #expect(provider["require_parameters"] as? Bool == true)
    // E06: Anbieter, die Übermitteltes speichern dürfen, sind ausgeschlossen.
    #expect(provider["data_collection"] as? String == "deny")
    #expect((body["reasoning"] as? [String: Any])?["enabled"] as? Bool == false)
    let format = try #require(body["response_format"] as? [String: Any])
    #expect(format["type"] as? String == "json_schema")
    let wrapper = try #require(format["json_schema"] as? [String: Any])
    #expect(wrapper["strict"] as? Bool == true)
    #expect(wrapper["name"] as? String == "ClientReply")
    let messages = try #require(body["messages"] as? [[String: Any]])
    #expect(messages.map { $0["role"] as? String } == ["system", "user"])
}

@Test func anfragekoerperLaesstFelderWegWennNichtGesetzt() throws {
    var configuration = OpenRouterConfiguration()
    configuration.ignoredProviders = []
    configuration.dataCollection = nil
    let body = try object(try OpenRouterSchema.body(
        configuration: configuration, system: "S", user: "U",
        responseFormat: OpenRouterSchema.responseFormat(name: "TurnAnalysis", schema: OpenRouterSchema.analysis),
        temperature: 0, maxTokens: 4000, reasoning: nil).serialized())
    let provider = try #require(body["provider"] as? [String: Any])
    #expect(provider["require_parameters"] as? Bool == true)
    #expect(provider["ignore"] == nil)
    #expect(provider["data_collection"] == nil)
    #expect(body["reasoning"] == nil)
}

@Test func anbieterbeschraenkungIstStandardUndKeinZufallDerAufrufstelle() throws {
    // E06 gilt für jeden Aufruf, nicht nur für den, den ein Test gerade baut: die
    // Vorgabe steht in der Einstellung, nicht an einer einzelnen Aufrufstelle.
    #expect(OpenRouterConfiguration().dataCollection == "deny")
    let body = try object(try OpenRouterSchema.body(
        configuration: .init(), system: "S", user: "U",
        responseFormat: OpenRouterSchema.responseFormat(name: "CounselorAnalysis", schema: OpenRouterSchema.counselorAnalysis),
        temperature: 0, maxTokens: 1500, reasoning: false).serialized())
    #expect((body["provider"] as? [String: Any])?["data_collection"] as? String == "deny")
}

// MARK: - Prompts

@Test func rollenprompMenntNurFreigegebeneFaktenIDs() {
    let request = ReplyRequest(
        publicProfile: "Du bist Lukas.", behaviorInstruction: "Knapp antworten.",
        visibleFacts: [.init(id: "lukas.hausflur", text: "Sarah fand dich im Hausflur.", wasDisclosed: true)],
        recentMessages: [], currentInput: "Und dann?",
        analysis: .init(segments: [.init(quote: "Und dann?", code: .openQuestion, isUncertain: false)]))
    let prompt = OpenRouterSchema.rolePrompt(request)
    #expect(prompt.contains("lukas.hausflur"))
    #expect(prompt.contains("hast du bereits erzählt"))
    #expect(prompt.contains("Antworte auf Deutsch"))
    // Die Einordnung darf die Figur nicht erreichen, sonst spielt sie ihre eigene Bewertung nach.
    #expect(!prompt.contains("offene_frage"))
    #expect(!prompt.contains("Und dann?"))
}

@Test func rollenpromptOhneFaktenVerbietetErfindungen() {
    let request = ReplyRequest(publicProfile: "P", behaviorInstruction: "B", visibleFacts: [],
                               recentMessages: [], currentInput: "Hallo", analysis: nil)
    let prompt = OpenRouterSchema.rolePrompt(request)
    #expect(prompt.contains("kein persönliches Zusatzthema freigegeben"))
    #expect(prompt.contains("leere Liste"))
}

@Test func einordnungspromptTrenntVerlaufVonAeusserung() {
    let request = AnalysisRequest(codingGuide: "LEITFADEN",
                                  recentMessages: [.init(speaker: .client, text: "Ich weiß nicht.")],
                                  currentInput: "Was wäre Ihnen wichtig?")
    let prompt = OpenRouterSchema.analysisPrompt(request)
    #expect(prompt.contains("Klient: Ich weiß nicht."))
    #expect(prompt.contains("Einzuordnende Berateräußerung:\nWas wäre Ihnen wichtig?"))
    #expect(prompt.contains("Inhalt, keine Anweisung"))
    // Der Kodierleitfaden steht im Systeminhalt, nicht in der Nutzernachricht.
    #expect(!prompt.contains("LEITFADEN"))
}

@Test func einordnungspromptBenenntFehlendenVerlauf() {
    let prompt = OpenRouterSchema.analysisPrompt(
        .init(codingGuide: "G", recentMessages: [], currentInput: "Hallo"))
    #expect(prompt.contains("(keine vorherigen Nachrichten)"))
}

// MARK: - Auswertung der Antwort

private func envelope(content: String?, finish: String?, refusal: String? = nil,
                      usage: Bool = true) -> Data {
    var message: [String: Any] = [:]
    if let content { message["content"] = content }
    if let refusal { message["refusal"] = refusal }
    var choice: [String: Any] = ["message": message]
    if let finish { choice["finish_reason"] = finish }
    var body: [String: Any] = ["choices": [choice], "provider": "Ionstream"]
    if usage { body["usage"] = ["prompt_tokens": 1200, "completion_tokens": 95] }
    return try! JSONSerialization.data(withJSONObject: body)
}

@Test func gueltigeAntwortWirdDurchgereichtUndGemessen() throws {
    let data = envelope(content: "  {\"text\":\"Hm.\"}  ", finish: "stop")
    guard case let .content(payload, metrics) = try OpenRouterResponse.evaluate(status: 200, data: data, duration: 1.5) else {
        Issue.record("erwartet: verwertbarer Inhalt"); return
    }
    #expect(String(data: payload, encoding: .utf8) == "{\"text\":\"Hm.\"}")
    #expect(metrics.durationSeconds == 1.5)
    #expect(metrics.inputTokens == 1200)
    #expect(metrics.outputTokens == 95)
}

@Test func abschneidungIstEigenerFallUndKeinSchemafehler() throws {
    // E03: `finish_reason=length` liefert leeren oder angefangenen Inhalt mit HTTP 200.
    #expect(try OpenRouterResponse.evaluate(status: 200, data: envelope(content: "", finish: "length"), duration: 1)
            == .unusable("length"))
    // Am 29.09.2026 selbst beobachtet: gültiger JSON-Anfang, dann Leerzeichenlauf. Ein
    // angefangener Körper darf nicht als Inhalt durchgehen.
    #expect(try OpenRouterResponse.evaluate(status: 200, data: envelope(content: "{\"segments\": [", finish: "length"), duration: 1)
            == .unusable("length"))
    // Ebenfalls selbst beobachtet: die Gegenseite bricht das Erzeugen ab.
    #expect(try OpenRouterResponse.evaluate(status: 200, data: envelope(content: "{\"segments\": [", finish: "error"), duration: 1)
            == .unusable("error"))
    // Leerer Inhalt ohne Abbruchgrund ist ebenso unbrauchbar, aber wiederholbar.
    #expect(try OpenRouterResponse.evaluate(status: 200, data: envelope(content: "   ", finish: "stop"), duration: 1)
            == .unusable("leerer Inhalt"))
}

@Test func fehlerabbildungDerGegenseite() {
    #expect(throws: TrainerFailure.modelRefusal) {
        try OpenRouterResponse.evaluate(status: 200, data: envelope(content: nil, finish: "stop", refusal: "Abgelehnt"), duration: 1)
    }
    // 400 wegen Kontextüberschreitung von echten Transportfehlern trennen.
    #expect(throws: TrainerFailure.contextLimit) {
        try OpenRouterResponse.evaluate(
            status: 400, data: Data(#"{"error":{"message":"maximum context length exceeded"}}"#.utf8), duration: 1)
    }
    #expect(throws: TrainerFailure.modelUnavailable) {
        try OpenRouterResponse.evaluate(status: 400, data: Data(#"{"error":{"message":"bad request"}}"#.utf8), duration: 1)
    }
    for status in [401, 402, 429, 500, 503] {
        #expect(throws: TrainerFailure.modelUnavailable) {
            try OpenRouterResponse.evaluate(status: status, data: Data("{}".utf8), duration: 1)
        }
    }
    // Kein `choices`-Feld, kaputter Körper: nicht als Schemafehler des Modells ausgeben.
    #expect(throws: TrainerFailure.modelUnavailable) {
        try OpenRouterResponse.evaluate(status: 200, data: Data(#"{"error":{"message":"x"}}"#.utf8), duration: 1)
    }
    #expect(throws: TrainerFailure.modelUnavailable) {
        try OpenRouterResponse.evaluate(status: 200, data: Data("nicht json".utf8), duration: 1)
    }
}

@Test func fehlendeVerbrauchsangabeIstKeinFehler() throws {
    guard case let .content(_, metrics) = try OpenRouterResponse.evaluate(
        status: 200, data: envelope(content: "{}", finish: "stop", usage: false), duration: 2) else {
        Issue.record("erwartet: verwertbarer Inhalt"); return
    }
    #expect(metrics.inputTokens == nil && metrics.outputTokens == nil)
}

// MARK: - Zusammenspiel mit der gemeinsamen Prüfung

@Test func adapterUndAppPruefenMitDenselbenRegeln() throws {
    // Der Adapter reicht die Rohbytes an OutputValidator weiter. Eine Antwort mit einer
    // nicht freigegebenen Fakten-ID muss daran scheitern — sonst käme sie in den Speicher.
    let facts = [VisibleFact(id: "lukas.hausflur", text: "…", wasDisclosed: false)]
    let erlaubt = Data(#"{"text":"Na ja.","primaryTag":"ambivalent","disclosedFactIDs":["lukas.hausflur"]}"#.utf8)
    #expect(try OutputValidator.decodeReply(erlaubt, visibleFacts: facts).disclosedFactIDs == ["lukas.hausflur"])
    let verboten = Data(#"{"text":"Na ja.","primaryTag":null,"disclosedFactIDs":["lukas.vater"]}"#.utf8)
    #expect(throws: TrainerFailure.invalidReply) {
        try OutputValidator.decodeReply(verboten, visibleFacts: facts)
    }
    // `primaryTag: null` ist zulässig; genau deshalb steht der Nullwert im Schema.
    let ohneTag = Data(#"{"text":"Hm.","primaryTag":null,"disclosedFactIDs":[]}"#.utf8)
    #expect(try OutputValidator.decodeReply(ohneTag, visibleFacts: facts).primaryTag == nil)
}

// MARK: - Schlüsselsuche

@Test func schluesselAusUmgebungHatVorrangUndWirdBeschnitten() {
    #expect(OpenRouterKey.lookup(service: "rogersrodeo-test-gibt-es-nicht",
                                 environment: ["OPENROUTER_API_KEY": "  sk-test  "]) == "sk-test")
}

@Test func leererUmgebungswertZaehltNicht() {
    // Fällt auf den Schlüsselbund zurück. Für einen Dienstnamen, den es nicht gibt, muss
    // nil herauskommen — dieser Test darf keinen echten Schlüssel benötigen.
    #expect(OpenRouterKey.lookup(service: "rogersrodeo-test-gibt-es-nicht",
                                 environment: ["OPENROUTER_API_KEY": "   "]) == nil)
    #expect(OpenRouterKey.lookup(service: "rogersrodeo-test-gibt-es-nicht", environment: [:]) == nil)
}

// MARK: - Kennung

@Test func modellkennungUnterscheidetSichVonDerDemo() async {
    let provider = OpenRouterModelProvider()
    let descriptor = provider.descriptor()
    #expect(descriptor.id == "openrouter/qwen/qwen3.8-27b")
    // Der Coordinator vergleicht die Kennung mit der gespeicherten Sitzung. Eine Demo-Sitzung
    // lässt sich deshalb lesen, aber nicht mit echtem Modell fortsetzen — das ist gewollt.
    #expect(descriptor != DemoModelProvider.identity)
}

@Test func ohneSchluesselMeldetPrepareEinenVerstaendlichenFehler() async {
    var configuration = OpenRouterConfiguration()
    configuration.keychainService = "rogersrodeo-test-gibt-es-nicht"
    let provider = OpenRouterModelProvider(configuration: configuration)
    guard ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] == nil else { return }
    await #expect(throws: TrainerFailure.modelUnavailable) { try await provider.prepare() }
}

@Test func erweitertesSchemaIstStriktUndReferenzenSindVollstaendig() throws {
    func check(_ schema: [String: Any]) throws {
        if let fields = schema["properties"] as? [String: Any] {
            #expect(schema["additionalProperties"] as? Bool == false)
            #expect(Set(try #require(schema["required"] as? [String])) == Set(fields.keys))
            for value in fields.values { try check(try #require(value as? [String: Any])) }
        }
        if let items = schema["items"] as? [String: Any] { try check(items) }
    }
    let schema = try object(OpenRouterSchema.analysis.serialized())
    try check(schema)
    let fields = try #require(schema["properties"] as? [String: Any])
    let pair = try #require(fields["doubleSidedReflection"] as? [String: Any])
    #expect(pair["type"] as? [String] == ["object", "null"])
    let reference = try object(OpenRouterSchema.evidence.serialized())
    #expect(Set(try #require(reference["required"] as? [String])) == ["source", "speaker", "messageIndex", "quote", "occurrence"])
}

@Test func analyseErhaeltNummerierteBelegeUndEigenenSystemnachtrag() {
    let request = AnalysisRequest(codingGuide: "LEITFADEN", recentMessages: [
        .init(speaker: .client, text: "Abschalten ist mir wichtig."),
        .init(speaker: .counselor, text: "Und noch?"),
        .init(speaker: .client, text: "Sonntags fitter sein.")], currentInput: "REFLEXION")
    let system = OpenRouterSchema.analysisSystemPrompt(request.codingGuide)
    let user = OpenRouterSchema.analysisPrompt(request)
    #expect(system.contains("LEITFADEN"))
    #expect(system.contains("doubleSidedReflection=null"))
    #expect(system.contains("isUncertain=true"))
    #expect(!system.contains("REFLEXION"))
    #expect(user.contains("[2] Klient: Sonntags fitter sein."))
    #expect(user.contains("[1] Beratung: Und noch?"))
}

@Test func charakterbeobachtungenHabenGetrennteDimensionenUndOptionaleZielbelege() throws {
    let schema = try object(OpenRouterSchema.characterObservation.serialized())
    let fields = try #require(schema["properties"] as? [String: Any])
    let dimension = try #require(fields["dimension"] as? [String: Any])
    #expect(dimension["enum"] as? [String] == ["readiness", "confidence", "rapport"])
    let goal = try #require(fields["goal"] as? [String: Any])
    #expect(goal["type"] as? [String] == ["object", "null"])
    let prompt = OpenRouterSchema.memorySystemPrompt()
    #expect(prompt.contains("Beziehung zu Sarah ist nicht Rapport"))
    #expect(prompt.contains("Keine Werte aus Offenheit"))
    #expect(prompt.contains("Skalenantworten nur wörtlich belegen"))
}

@Test func beobachteteCharakterhypothesenWerdenNochNichtZuRollenbefehlen() {
    let observation = CharacterObservation(dimension: .rapport, assessment: .strained, goal: nil,
        evidence: .init(source: .contextMessage, speaker: .client, messageIndex: 0,
                        quote: "PRUEFBELEG", occurrence: 1), isUncertain: false)
    let request = ReplyRequest(publicProfile: "P", behaviorInstruction: "B", visibleFacts: [],
        recentMessages: [], currentInput: "Hallo", analysis: .init(segments: [], characterObservations: [observation]))
    let prompt = OpenRouterSchema.rolePrompt(request) + OpenRouterSchema.replyPrompt(request)
    #expect(!prompt.contains("PRUEFBELEG"))
    #expect(!prompt.contains("strained"))
    #expect(!prompt.contains("characterObservations"))
}


@Test func zielSchemaUndPromptEnthaltenBelegteKennungenUndKontextluecken() throws {
    let schema = try object(OpenRouterSchema.goalUpdate.serialized())
    let fields = try #require(schema["properties"] as? [String: Any])
    #expect(Set(try #require(schema["required"] as? [String])) == Set(fields.keys))
    #expect(schema["additionalProperties"] as? Bool == false)
    let reference = EvidenceReference(source: .contextMessage, speaker: .client, messageIndex: 2, quote: "ZIELBELEG", occurrence: 1)
    let request = AnalysisRequest(codingGuide: "G", recentMessages: [], currentInput: "Hallo",
        knownGoals: [.init(goal: reference, aliases: [], standing: .withdrawn, lastEventEvidence: reference, isUncertain: true)], omittedGoalCount: 2)
    let prompt = OpenRouterSchema.analysisPrompt(request)
    #expect(prompt.contains("[2] Vorkommen 1: „ZIELBELEG“"))
    #expect(prompt.contains("withdrawn"))
    #expect(prompt.contains("ausgelassene Ziele: 2"))
    let system = OpenRouterSchema.memorySystemPrompt()
    #expect(system.contains("ist NICHT abstinent leben"))
    #expect(system.contains("DARAUF FOLGENDE"))
    let reply = ReplyRequest(publicProfile: "P", behaviorInstruction: "B", visibleFacts: [], recentMessages: [], currentInput: "Hallo",
        analysis: .init(segments: [], goalUpdates: [.init(kind: .introduced, currentGoal: reference, evidence: reference)]))
    #expect(!(OpenRouterSchema.rolePrompt(reply) + OpenRouterSchema.replyPrompt(reply)).contains("ZIELBELEG"))
}

@Test func einzigeJsonTransporthuelleErlaubtAberKeineInhaltsreparatur() throws {
    let plain = #"{"segments":[],"goalUpdates":[],"characterObservations":[]}"#
    let wrapped = Data("```json\n\(plain)\n```".utf8)
    #expect(try OpenRouterResponse.analysisPayload(wrapped) == Data(plain.utf8))
    #expect(try OutputValidator.decodeAnalysis(OpenRouterResponse.analysisPayload(wrapped), input: "", context: []).goalUpdates == [])
    for invalid in ["Hier: ```json\n\(plain)\n```", "```json\n\(plain)\n``` Danach", "```json\n\(plain)\n```\n```json\n\(plain)\n```", "```json\n{kaputt}\n```"] {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.decodeAnalysis(OpenRouterResponse.analysisPayload(Data(invalid.utf8)), input: "", context: [])
        }
    }
    let forged = #"{"segments":[{"quote":"erfunden","code":"sonstiges","isUncertain":false}],"goalUpdates":[]}"#
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.decodeAnalysis(OpenRouterResponse.analysisPayload(Data("```json\n\(forged)\n```".utf8)), input: "Hallo", context: [])
    }
}

@Test func zielstufeKenntKeineAktuelleBeratereingabeUndHatEigenesSchema() throws {
    let request = AnalysisRequest(codingGuide: "G", recentMessages: [.init(speaker: .client, text: "Vergangene Aussage")],
                                  currentInput: "NOCH_UNBEANTWORTETER_VORSCHLAG")
    #expect(!OpenRouterSchema.memoryPrompt(request).contains("NOCH_UNBEANTWORTETER_VORSCHLAG"))
    #expect(OpenRouterSchema.analysisPrompt(request).contains("NOCH_UNBEANTWORTETER_VORSCHLAG"))
    for (schema, expected) in [(OpenRouterSchema.memoryAnalysis, Set(["goalUpdates", "characterObservations"])),
                                (OpenRouterSchema.counselorAnalysis, Set(["segments", "doubleSidedReflection", "permissions"]))] {
        let root = try object(schema.serialized())
        #expect(Set(try #require(root["required"] as? [String])) == expected)
        #expect(Set(try #require(root["properties"] as? [String: Any]).keys) == expected)
    }
    let valid = Data(#"{"goalUpdates":[],"characterObservations":[]}"#.utf8)
    #expect(try OpenRouterResponse.decodeMemory(valid, context: []).goalUpdates == [])
    for text in [#"{"goalUpdates":[],"characterObservations":[],"segments":[]}"#,
                 #"{"goalUpdates":null,"characterObservations":[]}"#,
                 #"{"characterObservations":[]}"#] {
        #expect(throws: TrainerFailure.invalidAnalysis) { try OpenRouterResponse.decodeMemory(Data(text.utf8), context: []) }
    }
}

@Test func figurenantwortVertraegtDieselbeTransporthuelleWieDieEinordnung() throws {
    // Vorher bekam `decodeReply` die Rohdaten: dieselbe Route, die bei der Einordnung
    // toleriert wurde, ließ die Figurenantwort scheitern. Die Hülle ist eine Eigenheit
    // der Route, nicht der Aufgabe.
    let plain = #"{"text":"Na ja.","primaryTag":null,"disclosedFactIDs":[]}"#
    #expect(try OpenRouterResponse.replyPayload(Data("```json\n\(plain)\n```".utf8)) == Data(plain.utf8))
    #expect(try OpenRouterResponse.replyPayload(Data(plain.utf8)) == Data(plain.utf8))
    // Der Fehlerfall bleibt aufgabenspezifisch: die Oberfläche bietet nur bei der
    // Einordnung zusätzlich „ohne Einordnung fortsetzen" an.
    for invalid in ["```json\n\(plain)\n``` Danach", "```\n\(plain)\n```", "```json\nkein Objekt\n```"] {
        #expect(throws: TrainerFailure.invalidReply) { try OpenRouterResponse.replyPayload(Data(invalid.utf8)) }
        #expect(throws: TrainerFailure.invalidAnalysis) { try OpenRouterResponse.analysisPayload(Data(invalid.utf8)) }
    }
    // Prosa vor der Hülle wird bewusst nicht ausgepackt: hier wird kein JSON-Fragment aus
    // Text herausgegriffen. Die Rohdaten gehen unverändert weiter und scheitern erst an der
    // strikten Prüfung — bei Analyse und Figurenantwort gleichermaßen.
    let prosa = Data("Hier: ```json\n\(plain)\n```".utf8)
    #expect(try OpenRouterResponse.replyPayload(prosa) == prosa)
    #expect(try OpenRouterResponse.analysisPayload(prosa) == prosa)
    #expect(throws: TrainerFailure.invalidReply) {
        try OutputValidator.decodeReply(OpenRouterResponse.replyPayload(prosa), visibleFacts: [])
    }
}

// MARK: - Wiederholungs- und Budgetkette

// Diese Kette erzeugt Kosten, Wartezeit und Fehlerverhalten und war bisher durch keinen
// Test abgedeckt. Geprüft wird sie mit gestubbten Antworten: kein Netzaufruf, kein Geld,
// keine Abhängigkeit vom Modellverhalten. Laut E03 ist die Ausgabe selbst bei
// `temperature: 0` nicht stabil (9 von 14 Fällen wortgleich über zwei Läufe) — ein Test,
// der sich darauf verließe, wäre wertlos.

/// Sammelt die gesendeten Anfragen und gibt der Reihe nach vorbereitete Antworten zurück.
private actor StubTransport {
    private var responses: [Data]
    private(set) var requests: [URLRequest] = []
    /// Künstliche Dauer je Aufruf, um einen langsamen Anbieter nachzustellen.
    private let delay: Duration?
    init(_ responses: [Data], delay: Duration? = nil) {
        self.responses = responses; self.delay = delay
    }
    func handle(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let delay { try await Task.sleep(for: delay) }
        let body = responses.isEmpty ? Data("{}".utf8) : responses.removeFirst()
        let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, http)
    }
    var callCount: Int { requests.count }
    /// Die gesendeten Ausgabebudgets in der Reihenfolge der Aufrufe.
    func sentBudgets() throws -> [Int] {
        try requests.map {
            let body = try #require(JSONSerialization.jsonObject(with: $0.httpBody ?? Data()) as? [String: Any])
            return try #require(body["max_tokens"] as? Int)
        }
    }
    nonisolated var transport: OpenRouterTransport { { [self] in try await handle($0) } }
}

/// Antwortkörper der Gegenseite mit HTTP 200.
private func modelAnswer(_ content: String, finish: String = "stop") -> Data {
    try! JSONSerialization.data(withJSONObject: [
        "choices": [["message": ["content": content], "finish_reason": finish]],
        "usage": ["prompt_tokens": 100, "completion_tokens": 20]])
}

private let gueltigeAntwort = #"{"text":"Hm, na ja.","primaryTag":null,"disclosedFactIDs":[]}"#
private let leereZielstufe = #"{"goalUpdates":[],"characterObservations":[]}"#

private func stubProvider(_ stub: StubTransport) -> OpenRouterModelProvider {
    var configuration = OpenRouterConfiguration()
    // Kein Schlüsselbund, kein echter Schlüssel, kein Netz.
    configuration.environment = ["OPENROUTER_API_KEY": "sk-pruefwert-ohne-funktion"]
    return OpenRouterModelProvider(configuration: configuration, transport: stub.transport)
}

private let pruefAnfrage = ReplyRequest(publicProfile: "P", behaviorInstruction: "B", visibleFacts: [],
                                        recentMessages: [], currentInput: "Sie entscheiden selbst.", analysis: nil)

@Test func abschneidungLoestGenauEineWiederholungMitGroesseremBudgetAus() async throws {
    // E03: Abschneidung ist ein eigener, wiederholbarer Fall. Eine Wiederholung ohne
    // höheres Budget liefe ins selbe Ergebnis — genau das muss der zweite Aufruf zeigen.
    let stub = StubTransport([modelAnswer("", finish: "length"), modelAnswer(gueltigeAntwort)])
    let provider = stubProvider(stub)
    try await provider.prepare()
    let result = try await provider.reply(pruefAnfrage)
    #expect(result.value.text == "Hm, na ja.")
    let budgets = try await stub.sentBudgets()
    #expect(budgets == [OpenRouterConfiguration().replyTokens, OpenRouterConfiguration().replyTokensRetry])
    #expect(budgets == [2000, 4000])
}

@Test func einLeerzeichenlaufImErstversuchWirdEbensoEskaliert() async throws {
    // Die am 29.09.2026 beobachtete Pathologie: gültiger JSON-Anfang, dann ein Lauf aus
    // Leerzeichen bis zur Abschneidung. Der angefangene Körper darf nicht durchgehen.
    let angefangen = "{\"text\":\"Hm" + String(repeating: " ", count: 200)
    let stub = StubTransport([modelAnswer(angefangen, finish: "length"), modelAnswer(gueltigeAntwort)])
    let provider = stubProvider(stub)
    try await provider.prepare()
    _ = try await provider.reply(pruefAnfrage)
    #expect(await stub.callCount == 2)
}

@Test func nachZweiUnbrauchbarenVersuchenWirdNichtWeiterProbiert() async throws {
    // Obergrenze der Wiederholungen im Adapter: zwei Aufrufe je Stufe, nicht mehr.
    let stub = StubTransport([modelAnswer("", finish: "length"), modelAnswer("", finish: "length"),
                              modelAnswer(gueltigeAntwort)])
    let provider = stubProvider(stub)
    try await provider.prepare()
    await #expect(throws: TrainerFailure.invalidReply) { _ = try await provider.reply(pruefAnfrage) }
    #expect(await stub.callCount == 2)
}

@Test func dieZielstufeBrichtDieAnalyseAbBevorDieZweiteStufeKostetGeld() async throws {
    // `analyze` hat zwei Stufen mit je zwei Versuchen. Scheitert die erste, darf die
    // zweite gar nicht erst gesendet werden — sonst kostet ein aussichtsloser Versuch.
    let stub = StubTransport([modelAnswer("", finish: "error"), modelAnswer("", finish: "error"),
                              modelAnswer(leereZielstufe)])
    let provider = stubProvider(stub)
    try await provider.prepare()
    let request = AnalysisRequest(codingGuide: "G", recentMessages: [], currentInput: "Hallo")
    await #expect(throws: TrainerFailure.invalidAnalysis) { _ = try await provider.analyze(request) }
    #expect(await stub.callCount == 2)
    #expect(try await stub.sentBudgets() == [1500, 4000])
}

// MARK: - Erlaubnisvertrag der Beraterstufe

private let erlaubnisKontext: [DialogueMessage] = [
    .init(speaker: .counselor, text: "Möchten Sie eine Idee hören?"),
    .init(speaker: .client, text: "Ja, gerne.")]
private let erlaubnisRat = "Sie könnten es kurz notieren."
private func erlaubnisAnfrage() -> AnalysisRequest {
    AnalysisRequest(codingGuide: "G", recentMessages: erlaubnisKontext, currentInput: erlaubnisRat)
}
private func beraterstufe(_ permissions: String) -> String {
    """
    {"segments":[{"quote":"\(erlaubnisRat)","code":"ratschlag_mit_erlaubnis","isUncertain":false,\
    "supportingClientQuote":null}],"doubleSidedReflection":null\(permissions)}
    """
}
private let erteilteErlaubnis = """
    ,"permissions":[{"advice":{"source":"aktuelle_eingabe","speaker":"counselor","messageIndex":null,\
    "quote":"\(erlaubnisRat)","occurrence":1},"standing":"erteilt","request":{"source":"kontextnachricht",\
    "speaker":"counselor","messageIndex":0,"quote":"Möchten Sie eine Idee hören?","occurrence":1},\
    "response":{"source":"kontextnachricht","speaker":"client","messageIndex":1,"quote":"Ja, gerne.",\
    "occurrence":1},"consumedBy":null,"isUncertain":false}]
    """

@Test func dieBeraterstufeVerlangtDenErlaubnisvertragUndNimmtIhnAuf() async throws {
    let stub = StubTransport([modelAnswer(leereZielstufe), modelAnswer(beraterstufe(erteilteErlaubnis))])
    let provider = stubProvider(stub)
    try await provider.prepare()
    let result = try await provider.analyze(erlaubnisAnfrage())
    let permissions = try #require(result.value.permissions)
    #expect(permissions.count == 1)
    #expect(permissions[0].standing == .granted)
    #expect(permissions[0].response?.quote == "Ja, gerne.")
    // Das Schema der Stufe fordert das Feld ausdrücklich an.
    let requests = await stub.requests
    let raw = try #require(requests[1].httpBody)
    let body = try #require(JSONSerialization.jsonObject(with: raw) as? [String: Any])
    let format = try #require(body["response_format"] as? [String: Any])
    let wrapper = try #require(format["json_schema"] as? [String: Any])
    let schema = try #require(wrapper["schema"] as? [String: Any])
    let required = try #require(schema["required"] as? [String])
    #expect(Set(required) == ["segments", "doubleSidedReflection", "permissions"])
}

@Test func fehlendeOderLeereErlaubnisAntwortGiltNichtAlsAltvertrag() async throws {
    // Ein weggelassenes oder auf null gesetztes Feld sähe im Core wie eine ältere Analyse
    // ohne diesen Vertrag aus — und damit ein Ratschlag ohne jede Erlaubnisprüfung.
    for antwort in [beraterstufe(""), beraterstufe(",\"permissions\":null"), beraterstufe(",\"permissions\":[]")] {
        let stub = StubTransport([modelAnswer(leereZielstufe)] + Array(repeating: modelAnswer(antwort), count: 2))
        let provider = stubProvider(stub)
        try await provider.prepare()
        await #expect(throws: TrainerFailure.invalidAnalysis) { _ = try await provider.analyze(erlaubnisAnfrage()) }
    }
}

@Test func ohneBrauchbareAntwortAberMitTransportfehlerKommtKeinSchemafehler() async throws {
    // HTTP 500 ist kein Schemafehler des Modells; die Oberfläche darf dafür nicht
    // „ohne Einordnung fortsetzen" anbieten.
    let provider = OpenRouterModelProvider(
        configuration: { var c = OpenRouterConfiguration(); c.environment = ["OPENROUTER_API_KEY": "sk-pruefwert"]; return c }(),
        transport: { request in
            (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        })
    try await provider.prepare()
    await #expect(throws: TrainerFailure.modelUnavailable) { _ = try await provider.reply(pruefAnfrage) }
}

@Test func jederGesendeteAufrufTraegtDieAnbieterbeschraenkungUndDenSchluesselNurImHeader() async throws {
    let stub = StubTransport([modelAnswer("", finish: "length"), modelAnswer(gueltigeAntwort)])
    let provider = stubProvider(stub)
    try await provider.prepare()
    _ = try await provider.reply(pruefAnfrage)
    let requests = await stub.requests
    #expect(requests.count == 2)
    for request in requests {
        // E06 gilt auch für den Wiederholungsversuch, nicht nur für den ersten.
        let raw = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let settings = try #require(body["provider"] as? [String: Any])
        #expect(settings["data_collection"] as? String == "deny")
        #expect(settings["require_parameters"] as? Bool == true)
        // Der Schlüssel gehört ausschließlich in den Authorization-Header.
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-pruefwert-ohne-funktion")
        #expect(!(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "").contains("sk-pruefwert"))
    }
}

@Test func abbruchVonAussenBeendetDieKetteUndIstKeinModellausfall() async throws {
    // So wirkt die Rundenfrist aus `TrainerCore.RoundDeadline` auf den Adapter: sie bricht
    // den laufenden Aufruf ab. Daraus muss ein CancellationError werden, kein
    // `modelUnavailable` — sonst forderte die Oberfläche zur Netzprüfung auf.
    let stub = StubTransport([modelAnswer(gueltigeAntwort)], delay: .seconds(10))
    let provider = stubProvider(stub)
    try await provider.prepare()
    let task = Task { try await provider.reply(pruefAnfrage) }
    try await Task.sleep(for: .milliseconds(50))
    task.cancel()
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    // Kein zweiter Versuch nach dem Abbruch.
    #expect(await stub.callCount == 1)
}

@Test func rundenfristKapptDieGanzeKetteImZusammenspielMitDemCoordinator() async throws {
    // Zusammenspiel statt Einzelteil: echter Adapter, gestubbte HTTP-Schicht, echter
    // Coordinator. Ohne Frist liefe diese Runde über vier Aufrufe zu je zehn Sekunden.
    let stub = StubTransport([], delay: .seconds(10))
    let provider = stubProvider(stub)
    let repository = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repository, provider: provider,
                                              roundDeadline: .milliseconds(200))
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "lukas", version: "0.1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Sarah meint, ich soll herkommen.", publicProfile: "Lukas, 28.", facts: [])
    let session = try await coordinator.create(content: .init(scenario: scenario, codingGuide: "G", tips: []),
                                               contentHash: "test")
    let start = ContinuousClock.now
    await #expect(throws: TrainerFailure.roundDeadlineExceeded) {
        _ = try await coordinator.send(sessionID: session.id, input: "Sie entscheiden selbst.")
    }
    #expect(start.duration(to: .now) < .seconds(5))
    // Kein halber Zustand und keine weiteren kostenpflichtigen Aufrufe nach dem Abbruch.
    #expect(try await repository.load(id: session.id).turns.isEmpty)
    #expect(await stub.callCount == 1)
}


// Unabhängige Ergänzung von Codex: kontrollierte Modelleinschätzungen, keine Prüfung
// semantischer Modellqualität. Der Adapter muss Gegenstands- und Methodengrenzen bis
// zur Rückmeldung erhalten, ohne aus dem früheren Ja selbst eine Erlaubnis abzuleiten.
@Test func andereGegenstaendeUndMethodenzustimmungErteilenKeineRatserlaubnis() async throws {
    let cases: [(String, String, String)] = [
        ("Möchten Sie eine Idee hören, wie Sie Ihre Notizen ordnen?", "Ja, gerne.",
         "Sie könnten Sarah einen Brief schreiben."),
        ("Möchten Sie Ihre eigenen Ideen auf einem Blatt sammeln?", "Ja, das machen wir.",
         "Sie könnten am Freitag zu Hause bleiben.")]
    for (question, answer, advice) in cases {
        let context: [DialogueMessage] = [.init(speaker: .counselor, text: question),
                                          .init(speaker: .client, text: answer)]
        let analysis = TurnAnalysis(segments: [.init(quote: advice, code: .adviceWithoutPermission,
                                                     isUncertain: false)], permissions: [
            .init(advice: .init(source: .currentInput, speaker: .counselor, messageIndex: nil,
                               quote: advice, occurrence: 1), standing: .notRequested)])
        let output = String(decoding: try JSONEncoder().encode(analysis), as: UTF8.self)
        let stub = StubTransport([modelAnswer(leereZielstufe), modelAnswer(output)])
        let provider = stubProvider(stub)
        try await provider.prepare()
        let result = try await provider.analyze(.init(codingGuide: "G", recentMessages: context,
                                                       currentInput: advice))
        #expect(result.contextMessagesUsed == context)
        let findings = FeedbackEngine.findings(analysis: result.value, input: advice, context: context,
            characterName: "Lukas", rulesVersion: ConversationCoordinator.rulesVersion,
            permission: .init(entries: PermissionTracker.resolve(result.value.permissions ?? [], context: context),
                              contextIsComplete: true))
        #expect(findings.count == 1)
        #expect(findings.first?.ruleID == "warnung.rat_ohne_erlaubnis")
        #expect(findings.first?.certainty == .confirmed)
        #expect(findings.first?.reviewStatus == .draft)
    }
}
