//
//  EditTodoViewController.swift
//  BubblyToDo
//
//  Created by 밀가루 on 9/15/24.
//

import UIKit

class EditTodoViewController: UIViewController {
    var todoId: Int64 // 수정할 투두의 ID
    var todo: TodoDTO // 수정할 투두의 데이터

    let todoTextField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    let datePicker: UIDatePicker = {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        return datePicker
    }()
    
    let categoryPicker: UIPickerView = {
        let picker = UIPickerView()
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    var categoryDictionary: [String: (String?, Int64?)] = [:] // 카테고리 색상과 ID 저장
    var selectedCategory: String?
    var categories: [String] = [] // 카테고리 이름을 저장할 배열

    // 초기화 메서드 추가
    init(todoId: Int64, todo: TodoDTO) {
        self.todoId = todoId
        self.todo = todo
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        setupDoneButton()
        
        // 텍스트 필드의 텍스트 설정
        todoTextField.text = todo.todo // 전달받은 todo의 내용을 설정
        loadCategories()
        
        // 카테고리 로드가 완료된 후 기본 선택 설정
        DispatchQueue.main.async {
            // 기본적으로 선택될 카테고리 설정
            if let initialCategoryIndex = self.categories.firstIndex(of: self.todo.todoCategory) {
                self.categoryPicker.selectRow(initialCategoryIndex, inComponent: 0, animated: false)
                self.selectedCategory = self.todo.todoCategory
            } else if !self.categories.isEmpty {
                // 카테고리 배열이 비어있지 않으면 첫 번째 카테고리 선택
                self.categoryPicker.selectRow(0, inComponent: 0, animated: false)
                self.selectedCategory = self.categories[0]
            }
        }
        
        // 날짜 설정
        if let todoDate = convertStringToDate(todo.todoDate) {
            datePicker.date = todoDate // 날짜 피커에 DB에서 가져온 날짜 설정
        }
        
        print("todoId: \(todoId) / todo: \(todo.todo)")
    }
    
    func setupUI() {
        view.addSubview(todoTextField)
        view.addSubview(datePicker)
        view.addSubview(categoryPicker)
        
        // UIPickerView의 delegate와 dataSource 설정
        categoryPicker.delegate = self
        categoryPicker.dataSource = self
        
        NSLayoutConstraint.activate([
            todoTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            todoTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            todoTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            todoTextField.heightAnchor.constraint(equalToConstant: 40),
            
            datePicker.topAnchor.constraint(equalTo: todoTextField.bottomAnchor, constant: 20),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            categoryPicker.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 20),
            categoryPicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryPicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryPicker.heightAnchor.constraint(equalToConstant: 400),
        ])
    }
    
    func setupDoneButton() {
        // 내비게이션 바에 완료 버튼 추가
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "완료", style: .done, target: self, action: #selector(doneButtonTapped))
    }
    
    func loadCategories() {
        guard let url = URL(string: "http://localhost:8084/category") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching categories: \(error)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                let categoryDTOList = try JSONDecoder().decode([CategoryDTO].self, from: data)
                print("Fetched Categories: \(categoryDTOList)") // 추가된 디버깅
                
                self.categoryDictionary = Dictionary(uniqueKeysWithValues: categoryDTOList.map { ($0.category, ($0.categoryColor, $0.categoryId)) })

                self.categories = categoryDTOList.map { $0.category } // 카테고리 이름 배열로 저장
                
                DispatchQueue.main.async {
                    self.categoryPicker.reloadAllComponents()
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
        
        task.resume()
    }
    
    @objc func doneButtonTapped() {
        // 변경된 값을 확인하여 EditTodoDTO 생성
        let updatedTodo = EditTodoDTO(
            todo: todoTextField.text?.isEmpty == true ? todo.todo : todoTextField.text!,
            todoDate: convertDateToString(datePicker.date),
            todoCategory: selectedCategory ?? todo.todoCategory, // 선택된 카테고리가 없으면 기존 카테고리 사용
            todoCategoryColor: todo.todoCategoryColor // 기존 카테고리 색상 유지
        )

        print("updatedTodo \(updatedTodo)")

        // 서버에 수정 요청
        updateTodoOnServer(todoId: todoId, todo: updatedTodo) { success, message in
            DispatchQueue.main.async {
                if success {
                    // 성공 메시지 표시 후 이전 화면으로 돌아가기
                    let alert = UIAlertController(title: "성공", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                        self.navigationController?.popViewController(animated: true)
                    }))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    // 오류 메시지 표시
                    let errorAlert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "확인", style: .default, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                }
            }
        }
    }

    // MARK: - 날짜 변환 메서드
    private func convertStringToDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"  // 적절한 형식으로 설정
        return dateFormatter.date(from: dateString)
    }

    private func convertDateToString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"  // 원하는 형식으로 변경
        return dateFormatter.string(from: date)
    }

    // 서버에 수정 요청
    func updateTodoOnServer(todoId: Int64, todo: EditTodoDTO, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "http://localhost:8084/bubbly-todo/update/\(todoId)") else {
            completion(false, "유효한 URL이 아닙니다.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST" // POST 요청
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(todo) // EditTodoDTO를 JSON으로 인코딩
            print("Sending JSON: \(String(data: jsonData, encoding: .utf8) ?? "")") // 디버깅
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error updating todo: \(error)")
                    completion(false, "업데이트 실패: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code: \(httpResponse.statusCode)") // 응답 상태 코드 확인
                    if httpResponse.statusCode == 200, let data = data,
                       let message = String(data: data, encoding: .utf8) {
                        // 성공 메시지를 반환
                        completion(true, message)
                    } else {
                        // 실패 메시지를 반환
                        let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "업데이트할 수 없습니다."
                        completion(false, errorMessage)
                    }
                }
            }
            
            task.resume()
        } catch {
            print("Error encoding todo: \(error)")
            completion(false, "업데이트 실패: \(error.localizedDescription)")
        }
    }

}

// UIPickerViewDelegate 및 UIPickerViewDataSource 확장
extension EditTodoViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1 // 컴포넌트 개수
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return categories.count // 카테고리 개수
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return categories[row] // 카테고리 이름 반환
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedCategory = categories[row] // 선택된 카테고리 저장
    }
}