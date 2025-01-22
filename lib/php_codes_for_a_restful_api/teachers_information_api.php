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
        // Create a new Teacher
        $data = json_decode(file_get_contents('php://input'), true);
        $name = $data['name'] ?? null;
        $surname = $data['surname'] ?? null;
        $IdNumber = $data['IdNumber'] ?? null;
        $assignedClass = $data['assignedClass'] ?? null;
        $gender = $data['gender'] ?? null;
        $dateOfBirth = $data['dateOfBirth'] ?? null;
        $phoneNumber = $data['phoneNumber'] ?? null;
        $paymentPurpose = $data['paymentPurpose'] ?? null;
        $isPaid = $data['isPaid'] ?? null;
        $paymentAmount = $data['paymentAmount'] ?? null;
        $paymentDate = $data['paymentDate'] ?? null;
        $email = $data['email'] ?? null;
        $address = $data['address'] ?? null;
        $hireDate = $data['hireDate'] ?? null;
        $qualifications = $data['qualifications'] ?? null;
        $employmentStatus = $data['employmentStatus'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$name || !$surname || !$IdNumber || !$gender || !$dateOfBirth || !$phoneNumber || !$paymentPurpose || !$paymentAmount || !$email || !$address || !$hireDate || !$qualifications || !$employmentStatus) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO Teachers (name, surname, IdNumber, assignedClass, gender, dateOfBirth, phoneNumber, paymentPurpose, isPaid, paymentAmount, paymentDate, email, address, hireDate, qualifications, employmentStatus, termId) VALUES (:name, :surname, :IdNumber, :assignedClass, :gender, :dateOfBirth, :phoneNumber, :paymentPurpose, :isPaid, :paymentAmount, :paymentDate, :email, :address, :hireDate, :qualifications, :employmentStatus, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':name' => $name,
            ':surname' => $surname,
            ':IdNumber' => $IdNumber,
            ':assignedClass' => $assignedClass,
            ':gender' => $gender,
            ':dateOfBirth' => $dateOfBirth,
            ':phoneNumber' => $phoneNumber,
            ':paymentPurpose' => $paymentPurpose,
            ':isPaid' => $isPaid,
            ':paymentAmount' => $paymentAmount,
            ':paymentDate' => $paymentDate,
            ':email' => $email,
            ':address' => $address,
            ':hireDate' => $hireDate,
            ':qualifications' => $qualifications,
            ':employmentStatus' => $employmentStatus,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Teacher created successfully']);
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

            $sql = "SELECT * FROM Teachers WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $teacher = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($teacher) {
                echo json_encode($teacher);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'Teacher not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM Teachers";
            $stmt = $pdo->query($sql);
            $teachers = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($teachers);
        }
        break;

    case 'PUT':
        // Update an existing Teacher
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $name = $data['name'] ?? null;
        $surname = $data['surname'] ?? null;
        $IdNumber = $data['IdNumber'] ?? null;
        $assignedClass = $data['assignedClass'] ?? null;
        $gender = $data['gender'] ?? null;
        $dateOfBirth = $data['dateOfBirth'] ?? null;
        $phoneNumber = $data['phoneNumber'] ?? null;
        $paymentPurpose = $data['paymentPurpose'] ?? null;
        $isPaid = $data['isPaid'] ?? null;
        $paymentAmount = $data['paymentAmount'] ?? null;
        $paymentDate = $data['paymentDate'] ?? null;
        $email = $data['email'] ?? null;
        $address = $data['address'] ?? null;
        $hireDate = $data['hireDate'] ?? null;
        $qualifications = $data['qualifications'] ?? null;
        $employmentStatus = $data['employmentStatus'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$name || !$surname || !$IdNumber || !$gender || !$dateOfBirth || !$phoneNumber || !$paymentPurpose || !$paymentAmount || !$email || !$address || !$hireDate || !$qualifications || !$employmentStatus) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE Teachers SET name = :name, surname = :surname, IdNumber = :IdNumber, assignedClass = :assignedClass, gender = :gender, dateOfBirth = :dateOfBirth, phoneNumber = :phoneNumber, paymentPurpose = :paymentPurpose, isPaid = :isPaid, paymentAmount = :paymentAmount, paymentDate = :paymentDate, email = :email, address = :address, hireDate = :hireDate, qualifications = :qualifications, employmentStatus = :employmentStatus, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':name' => $name,
            ':surname' => $surname,
            ':IdNumber' => $IdNumber,
            ':assignedClass' => $assignedClass,
            ':gender' => $gender,
            ':dateOfBirth' => $dateOfBirth,
            ':phoneNumber' => $phoneNumber,
            ':paymentPurpose' => $paymentPurpose,
            ':isPaid' => $isPaid,
            ':paymentAmount' => $paymentAmount,
            ':paymentDate' => $paymentDate,
            ':email' => $email,
            ':address' => $address,
            ':hireDate' => $hireDate,
            ':qualifications' => $qualifications,
            ':employmentStatus' => $employmentStatus,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Teacher updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific Teacher
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM Teachers WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Teacher deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'Teacher not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
