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
        // Create a new Withdrawal
        $data = json_decode(file_get_contents('php://input'), true);
        $date = $data['date'] ?? null;
        $amount = $data['amount'] ?? null;
        $withdrawalPurpose = $data['withdrawalPurpose'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$date || !$amount || !$withdrawalPurpose) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO Withdrawal (date, amount, withdrawalPurpose, termId) VALUES (:date, :amount, :withdrawalPurpose, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':date' => $date,
            ':amount' => $amount,
            ':withdrawalPurpose' => $withdrawalPurpose,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Withdrawal created successfully']);
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

            $sql = "SELECT * FROM Withdrawal WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $withdrawal = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($withdrawal) {
                echo json_encode($withdrawal);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'Withdrawal not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM Withdrawal";
            $stmt = $pdo->query($sql);
            $withdrawals = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode($withdrawals);
        }
        break;

    case 'PUT':
        // Update an existing Withdrawal
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $date = $data['date'] ?? null;
        $amount = $data['amount'] ?? null;
        $withdrawalPurpose = $data['withdrawalPurpose'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$date || !$amount || !$withdrawalPurpose) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE Withdrawal SET date = :date, amount = :amount, withdrawalPurpose = :withdrawalPurpose, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':date' => $date,
            ':amount' => $amount,
            ':withdrawalPurpose' => $withdrawalPurpose,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'Withdrawal updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific Withdrawal
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM Withdrawal WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'Withdrawal deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'Withdrawal not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
