<?php
include 'db.php';

// Set headers for CORS
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Get the HTTP method
$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'POST':
        // Create a new Student
        $data = json_decode(file_get_contents('php://input'), true);
        $name = $data['name'] ?? null;
        $surname = $data['surname'] ?? null;
        $regNumber = $data['regNumber'] ?? null;
        $class = $data['class'] ?? null;
        $gender = $data['gender'] ?? null;
        $age = $data['age'] ?? null;
        $phoneNumber = $data['phoneNumber'] ?? null;
        $paymentStatus = $data['paymentStatus'] ?? null;
        $isPresent = $data['isPresent'] ?? true;
        $presentDates = $data['presentDates'] ?? null;
        $absentDates = $data['absentDates'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$name || !$surname || !$regNumber || !$class || !$gender || !$age || !$phoneNumber || !$paymentStatus) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO Student (name, surname, regNumber, class, gender, age, phoneNumber, paymentStatus, isPresent, presentDates, absentDates, termId) VALUES (:name, :surname, :regNumber, :class, :gender, :age, :phoneNumber, :paymentStatus, :isPresent, :presentDates, :absentDates, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':name' => $name,
            ':surname' => $surname,
            ':regNumber' => $regNumber,
            ':class' => $class,
            ':gender' => $gender,
            ':age' => $age,
            ':phoneNumber' => $phoneNumber,
            ':paymentStatus' => $paymentStatus,
            ':isPresent' => $isPresent,
            ':presentDates' => $presentDates,
            ':absentDates' => $absentDates,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Student created successfully']);
        break;

    case 'GET':
        if (isset($_GET['id'])) {
            // Fetch a specific record
            $id = $_GET['id'];
            if (!$id) {
                http_response_code(400);
                echo json_encode(['message' => 'Invalid ID']);
                exit;
            }

            $sql = "SELECT * FROM Student WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $student = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($student) {
                echo json_encode($student);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'Student not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM Student";
            $stmt = $pdo->query($sql);
            $students = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($students);
        }
        break;

    case 'PUT':
        // Update an existing Student
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $name = $data['name'] ?? null;
        $surname = $data['surname'] ?? null;
        $regNumber = $data['regNumber'] ?? null;
        $class = $data['class'] ?? null;
        $gender = $data['gender'] ?? null;
        $age = $data['age'] ?? null;
        $phoneNumber = $data['phoneNumber'] ?? null;
        $paymentStatus = $data['paymentStatus'] ?? null;
        $isPresent = $data['isPresent'] ?? true;
        $presentDates = $data['presentDates'] ?? null;
        $absentDates = $data['absentDates'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$name || !$surname || !$regNumber || !$class || !$gender || !$age || !$phoneNumber || !$paymentStatus) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE Student SET name = :name, surname = :surname, regNumber = :regNumber, class = :class, gender = :gender, age = :age, phoneNumber = :phoneNumber, paymentStatus = :paymentStatus, isPresent = :isPresent, presentDates = :presentDates, absentDates = :absentDates, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':name' => $name,
            ':surname' => $surname,
            ':regNumber' => $regNumber,
            ':class' => $class,
            ':gender' => $gender,
            ':age' => $age,
            ':phoneNumber' => $phoneNumber,
            ':paymentStatus' => $paymentStatus,
            ':isPresent' => $isPresent,
            ':presentDates' => $presentDates,
            ':absentDates' => $absentDates,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Student updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific Student
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM Student WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Student deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'Student not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
