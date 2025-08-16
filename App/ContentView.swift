import SwiftUI
import PhotosUI


struct GrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var minHeight: CGFloat = 40
    var onHeightChange: ((CGFloat) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 20)
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textColor = UIColor.label
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        DispatchQueue.main.async {
            let size = uiView.sizeThatFits(CGSize(width: uiView.frame.width, height: .infinity))
            onHeightChange?(max(size.height, minHeight))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextEditor

        init(_ parent: GrowingTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
            parent.onHeightChange?(max(size.height, parent.minHeight))
        }
    }
}



struct QuestionSet: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var questions: [String]
    var answers: [String]
    var imagePaths: [String]

    init(id: UUID = UUID(), title: String, questions: [String], answers: [String], imagePaths: [String] = []) {
        self.id = id
        self.title = title
        self.questions = questions
        self.answers = answers
        self.imagePaths = imagePaths
    }
}

class QuestionSetsViewModel: ObservableObject {
    @Published var savedSets: [QuestionSet] = [] {
        didSet { saveSets() }
    }
    @Published var deletedSets: [QuestionSet] = [] {
        didSet { saveDeletedSets() }
    }
    
    private let savedKey = "SavedQuestionSets"
    private let deletedKey = "DeletedQuestionSets"

    init() {
        loadSets()
        loadDeletedSets()
    }

    func updateSet(_ updatedSet: QuestionSet) {
        if let index = savedSets.firstIndex(where: { $0.id == updatedSet.id }) {
            savedSets[index] = updatedSet
        }
    }

    func saveImage(_ image: UIImage, for questionIndex: Int, in setID: UUID) -> String? {
        let fileName = "\(setID.uuidString)-q\(questionIndex).png"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        if let data = image.pngData() {
            try? data.write(to: url)
            return fileName
        }
        return nil
    }

    func loadImage(from path: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(path)
        return UIImage(contentsOfFile: url.path)
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveSets() {
        if let data = try? JSONEncoder().encode(savedSets) {
            UserDefaults.standard.set(data, forKey: savedKey)
        }
    }

    private func loadSets() {
        if let data = UserDefaults.standard.data(forKey: savedKey),
           let sets = try? JSONDecoder().decode([QuestionSet].self, from: data) {
            savedSets = sets
        }
    }

    private func saveDeletedSets() {
        if let data = try? JSONEncoder().encode(deletedSets) {
            UserDefaults.standard.set(data, forKey: deletedKey)
        }
    }

    private func loadDeletedSets() {
        if let data = UserDefaults.standard.data(forKey: deletedKey),
           let sets = try? JSONDecoder().decode([QuestionSet].self, from: data) {
            deletedSets = sets
        }
    }

    // Move set to deletedSets (trash)
    func moveToDeleted(_ set: QuestionSet) {
        if let index = savedSets.firstIndex(where: { $0.id == set.id }) {
            savedSets.remove(at: index)
            deletedSets.append(set)
        }
    }
    
    // Restore set from trash back to savedSets
    func restoreSet(_ set: QuestionSet) {
        if let index = deletedSets.firstIndex(where: { $0.id == set.id }) {
            deletedSets.remove(at: index)
            savedSets.append(set)
        }
    }
    
    // Permanently delete set from trash
    func permanentlyDeleteSet(_ set: QuestionSet) {
        if let index = deletedSets.firstIndex(where: { $0.id == set.id }) {
            deletedSets.remove(at: index)
            saveDeletedSets()
        }
    }
}

struct ContentView: View {
    let mottos = [
        "Write. Reflect. Win.",
        "Turn errors into experience.",
        "Mistakes are proof you are trying.",
        "Learn fast. Fail smart. Improve always.",
        "Where mistakes become milestones.",
        "Mistakes fuel mastery",
        "Every fault shapes the future",
        "Mistakes are stepping stones to success."
    ]
    @State private var currentMotto: String = ""

    @StateObject var viewModel = QuestionSetsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Text("Welcome to")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .offset(y: -280)
                Text("Mistipad")
                    .font(.system(size: 90))
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .offset(y: -140)
                Divider()
                    .frame(height: 5)
                    .background(Color.orange)
                    .padding(.horizontal)
                    .offset(y: -80)
                Text(currentMotto)
                    .font(.largeTitle)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .offset(y: 40)
                NavigationLink(destination: SecondView()
                                .environmentObject(viewModel)) {
                    Text("Start")
                        .padding()
                        .frame(width: 210, height: 100)
                        .font(.system(size: 50))
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .offset(x: 1, y: 190)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yellow)
            .onAppear {
                currentMotto = mottos.randomElement() ?? ""
            }
        }
    }
}

struct SecondView: View {
    @EnvironmentObject var viewModel: QuestionSetsViewModel
    @State private var isCreatingNewSet = false
    @State private var editingSet: QuestionSet? = nil

    @Environment(\.editMode) private var editMode

    var body: some View {
        VStack {
            Text("Mistipad")
                .foregroundColor(.orange)
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .padding(.top, 20)

            VStack(spacing: 0) {
                Text("Every question turns")
                Text("mistakes into lessons")
            }
            .font(.system(size: 30))
            .multilineTextAlignment(.center)
            .padding(.bottom, 10)

            Divider()
                .frame(height: 5)
                .background(Color.orange)
                .padding(.horizontal)
                .padding(.bottom, 20)

            NavigationLink("Recently Deleted", destination: RecentlyDeletedView()
                .environmentObject(viewModel))
                .foregroundColor(.red)
                .padding(.bottom)

            List {
                ForEach(viewModel.savedSets) { set in
                    Button {
                        editingSet = set
                    } label: {
                        Text(set.title.isEmpty ? "Untitled Question Set" : set.title)
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .onDelete(perform: deleteSets)
                .onMove(perform: moveSets)
            }
            .listStyle(PlainListStyle())
            .toolbar {
                EditButton()  // <-- add an Edit button so user can toggle reorder mode
            }


            HStack {
                Spacer()
                Button(action: {
                    isCreatingNewSet = true
                }) {
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.top)
        }
        .navigationDestination(isPresented: Binding(
            get: { editingSet != nil },
            set: { newVal in if !newVal { editingSet = nil } }
        )) {
            if let editingSet = editingSet {
                ThirdView(questionSet: editingSet, isNewSet: false)
                    .environmentObject(viewModel)
            }
        }
        .navigationDestination(isPresented: $isCreatingNewSet) {
            ThirdView(questionSet: QuestionSet(title: "", questions: [""], answers: [""]), isNewSet: true)
                .environmentObject(viewModel)
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        for index in offsets {
            let set = viewModel.savedSets[index]
            viewModel.moveToDeleted(set)
        }
    }

    private func moveSets(from source: IndexSet, to destination: Int) {
        viewModel.savedSets.move(fromOffsets: source, toOffset: destination)
    }
}


struct RecentlyDeletedView: View {
    @EnvironmentObject var viewModel: QuestionSetsViewModel
    @State private var editingSet: QuestionSet? = nil

    var body: some View {
        VStack {
            Text("Recently Deleted")
                .font((.system(size: 40)))
                .foregroundColor(.red)
                .padding()

            List {
                ForEach(viewModel.deletedSets) { set in
                    HStack {
                        NavigationLink(destination: ThirdView(questionSet: set, isNewSet: false)
                            .environmentObject(viewModel)) {
                            Text(set.title.isEmpty ? "Untitled Question Set" : set.title)
                                .foregroundColor(.red)
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Button(action: {
                                viewModel.restoreSet(set)
                            }) {
                                VStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Restore")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: permanentlyDelete)
            }
            
            Button("Empty") {
                viewModel.deletedSets.removeAll()
            }
            .foregroundColor(.white)
            .frame(width: 80, height: 50)
            .font(.system(size: 20))
            .background(Color.red)
            .cornerRadius(15)
        }
        .navigationDestination(isPresented: Binding(
            get: { editingSet != nil },
            set: { newVal in if !newVal { editingSet = nil } }
        )) {
            if let editingSet = editingSet {
                ThirdView(questionSet: editingSet, isNewSet: false)
                    .environmentObject(viewModel)
            }
        }
    }
    private func moveSets(from source: IndexSet, to destination: Int) {
        viewModel.savedSets.move(fromOffsets: source, toOffset: destination)
    }
    private func permanentlyDelete(at offsets: IndexSet) {
        for index in offsets {
            let set = viewModel.deletedSets[index]
            viewModel.permanentlyDeleteSet(set)
        }
    }
}

struct ThirdView: View {
    @EnvironmentObject var viewModel: QuestionSetsViewModel

    @State var questionSet: QuestionSet
    var isNewSet: Bool

    @State private var selectedItems: [PhotosPickerItem?]
    @State private var selectedImages: [UIImage?]
    @State private var imagePaths: [String?]
    @State private var questionHeights: [CGFloat]
    @State private var answerHeights: [CGFloat]

    init(questionSet: QuestionSet, isNewSet: Bool) {
        self.isNewSet = isNewSet
        var set = questionSet
        if isNewSet && set.questions.isEmpty {
            set.questions.append("")
            set.answers.append("")
        }
        _questionSet = State(initialValue: set)

        let count = set.questions.count
        self._selectedItems = State(initialValue: Array(repeating: nil, count: count))
        self._selectedImages = State(initialValue: Array(repeating: nil, count: count))
        self._imagePaths = State(initialValue: Array(repeating: nil, count: count))
        self._questionHeights = State(initialValue: Array(repeating: 40, count: count))
        self._answerHeights = State(initialValue: Array(repeating: 40, count: count))
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Untitled Question Set", text: $questionSet.title)
                    .padding(8)
                    .font(.system(size: 30))
                    .frame(minHeight: 60)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.4), lineWidth: 1)
                    )
                    .onChange(of: questionSet.title) { _ in saveSet() }

                ForEach(questionSet.questions.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.system(size: 40))

                        ZStack(alignment: .topLeading) {
                            if questionSet.questions[i].isEmpty {
                                Text("Question:")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            }

                            GrowingTextEditor(
                                text: Binding(
                                    get: { questionSet.questions[i] },
                                    set: {
                                        questionSet.questions[i] = $0
                                        syncArrays()
                                        saveSet()
                                    }
                                ),
                                placeholder: "",
                                minHeight: questionHeights[i],
                                onHeightChange: { newHeight in
                                    if questionHeights[i] != newHeight {
                                        questionHeights[i] = newHeight
                                    }
                                }
                            )
                            .frame(minHeight: questionHeights[i])
                            .padding(8)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )

                        ZStack(alignment: .topLeading) {
                            if questionSet.answers[i].isEmpty {
                                Text("Answer:")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            }

                            GrowingTextEditor(
                                text: Binding(
                                    get: { questionSet.answers[i] },
                                    set: {
                                        questionSet.answers[i] = $0
                                        syncArrays()
                                        saveSet()
                                    }
                                ),
                                placeholder: "",
                                minHeight: answerHeights[i],
                                onHeightChange: { newHeight in
                                    if answerHeights[i] != newHeight {
                                        answerHeights[i] = newHeight
                                    }
                                }
                            )
                            .frame(minHeight: answerHeights[i])
                            .padding(8)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )


                        if i < selectedImages.count, let img = selectedImages[i] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                        }

                        PhotosPicker(selection: Binding(
                            get: { i < selectedItems.count ? selectedItems[i] : nil },
                            set: { newItem in
                                if i < selectedItems.count {
                                    selectedItems[i] = newItem
                                }
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        if i < selectedImages.count {
                                            selectedImages[i] = uiImage
                                            imagePaths[i] = viewModel.saveImage(uiImage, for: i, in: questionSet.id)
                                            saveSet()
                                        }
                                    }
                                }
                            }
                        ), matching: .images) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 30))
                        }
                    }
                    .padding(.top, 20)
                }

                Button("Add Question") {
                    questionSet.questions.append("")
                    questionSet.answers.append("")
                    selectedItems.append(nil)
                    selectedImages.append(nil)
                    imagePaths.append(nil)
                    saveSet()
                }
                .font(.system(size: 20))
                .padding()
                .frame(width: 160, height: 50)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)


                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .onAppear {
                syncArrays()
                loadImagesFromDisk()
                if questionSet.questions.isEmpty {
                    questionSet.questions.append("")
                    questionSet.answers.append("")
                    selectedItems.append(nil)
                    selectedImages.append(nil)
                    imagePaths.append(nil)
                    questionHeights.append(40)
                    answerHeights.append(40)
                }
            }
            .onDisappear {
                removeBlankQuestions()
                saveSet()
            }
        }
    }

    private func syncArrays() {
        let count = questionSet.questions.count
        while selectedItems.count < count { selectedItems.append(nil) }
        while selectedImages.count < count { selectedImages.append(nil) }
        while imagePaths.count < count { imagePaths.append(nil) }

        while selectedItems.count > count { selectedItems.removeLast() }
        while selectedImages.count > count { selectedImages.removeLast() }
        while imagePaths.count > count { imagePaths.removeLast() }
        while questionHeights.count < questionSet.questions.count {
            questionHeights.append(40)
        }
        while questionHeights.count > questionSet.questions.count {
            questionHeights.removeLast()
        }

        while answerHeights.count < questionSet.answers.count {
            answerHeights.append(40)
        }
        while answerHeights.count > questionSet.answers.count {
            answerHeights.removeLast()
        }

    }

    private func loadImagesFromDisk() {
        while questionSet.imagePaths.count < questionSet.questions.count {
            questionSet.imagePaths.append("")
        }

        self.imagePaths = questionSet.imagePaths.map { $0 }

        self.selectedImages = self.imagePaths.map { path in
            if let path = path, !path.isEmpty {
                return viewModel.loadImage(from: path)
            }
            return nil
        }
    }
    private func removeBlankQuestions() {
        var indicesToRemove: [Int] = []
        
        for i in questionSet.questions.indices {
            if questionSet.questions[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               questionSet.answers[i].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               (imagePaths[i] ?? "").isEmpty {
                indicesToRemove.append(i)
            }
        }
        
        for index in indicesToRemove.sorted(by: >) {
            questionSet.questions.remove(at: index)
            questionSet.answers.remove(at: index)
            selectedItems.remove(at: index)
            selectedImages.remove(at: index)
            imagePaths.remove(at: index)
            questionHeights.remove(at: index)
            answerHeights.remove(at: index)
        }
    }


    private func saveSet() {
        syncArrays()

        for i in 0..<selectedImages.count {
            if let image = selectedImages[i] {
                imagePaths[i] = viewModel.saveImage(image, for: i, in: questionSet.id)
            } else {
                imagePaths[i] = nil
            }
        }

        questionSet.imagePaths = imagePaths.map { $0 ?? "" }

        if let idx = viewModel.savedSets.firstIndex(where: { $0.id == questionSet.id }) {
            viewModel.savedSets[idx] = questionSet
        } else {
            viewModel.savedSets.append(questionSet)
        }
    }
}

#Preview {
    ContentView()
}
