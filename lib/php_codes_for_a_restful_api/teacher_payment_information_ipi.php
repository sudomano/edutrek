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
        // Create a new TeacherPayment
        $data = json_decode(file_get_contents('php://input'), true);
        $studentName = $data['studentName'] ?? null;
        $studentSurname = $data['studentSurname'] ?? null;
        $studentClass = $data['studentClass'] ?? null;
        $phoneNumber = $data['phoneNumber'] ?? null;
        $paymentPurpose = $data['paymentPurpose'] ?? null;
        $amountToPay = $data['amountToPay'] ?? null;
        $paymentDate = $data['paymentDate'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$studentName || !$studentSurname || !$studentClass || !$phoneNumber || !$paymentPurpose || !$amountToPay || !$paymentDate) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO TeacherPayment (studentName, studentSurname, studentClass, phoneNumber, paymentPurpose, amountToPay, paymentDate, termId) VALUES (:studentName, :studentSurname, :studentClass, :phoneNumber, :paymentPurpose, :amountToPay, :paymentDate, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':studentName' => $studentName,
            ':studentSurname' => $studentSurname,
            ':studentClass' => $studentClass,
            ':phoneNumber' => $phoneNumber,
            ':paymentPurpose' => $paymentPurpose,
            ':amountToPay' => $amountToPay,
            ':paymentDate' => $paymentDate,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Teacher payment created successfully']);
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

            $sql = "SELECT * FROM TeacherPayment WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $teacherPayment = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($teacherPayment) {
                echo json_encode($teacherPayment);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'Teacher payment not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM TeacherPayment";
            $stmt = $pdo->query($sql);
            $teacherPayments = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($teacherPayments);
        }
        break;

    case 'PUT':
        // Update an existing TeacherPayment
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $studentName = $data['studentName'] ?? null;
        $studentSurname = $data['studentSurname'] ?? null;
        $studentClass = $data['studentClass'] ?? null;
        $phoneNumber = $data['phoneNumber'] ?? null;
        $paymentPurpose = $data['paymentPurpose'] ?? null;
        $amountToPay = $data['amountToPay'] ?? null;
        $paymentDate = $data['paymentDate'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$studentName || !$studentSurname || !$studentClass || !$phoneNumber || !$paymentPurpose || !$amountToPay || !$paymentDate) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE TeacherPayment SET studentName = :studentName, studentSurname = :studentSurname, studentClass = :studentClass, phoneNumber = :phoneNumber, paymentPurpose = :paymentPurpose, amountToPay = :amountToPay, paymentDate = :paymentDate, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':studentName' => $studentName,
            ':studentSurname' => $studentSurname,
            ':studentClass' => $studentClass,
            ':phoneNumber' => $phoneNumber,
            ':paymentPurpose' => $paymentPurpose,
            ':amountToPay' => $amountToPay,
            ':paymentDate' => $paymentDate,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Teacher payment updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific TeacherPayment
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM TeacherPayment WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Teacher payment deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'Teacher payment not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
