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
        // Create a new User
        $data = json_decode(file_get_contents('php://input'), true);
        $username = $data['username'] ?? null;
        $password = $data['password'] ?? null;
        $role = $data['role'] ?? null;
        $securityQuestions = $data['securityQuestions'] ?? null;
        $securityAnswers = $data['securityAnswers'] ?? null;
        $phone = $data['phone'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$username || !$password || !$role || !$securityQuestions || !$securityAnswers || !$phone) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "INSERT INTO User (username, password, role, securityQuestions, securityAnswers, phone, termId) VALUES (:username, :password, :role, :securityQuestions, :securityAnswers, :phone, :termId)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':username' => $username,
            ':password' => $password,
            ':role' => $role,
            ':securityQuestions' => json_encode($securityQuestions),
            ':securityAnswers' => json_encode($securityAnswers),
            ':phone' => $phone,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'User created successfully']);
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

            $sql = "SELECT * FROM User WHERE id = :id";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([':id' => $id]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($user) {
                // Decode JSON fields
                $user['securityQuestions'] = json_decode($user['securityQuestions'], true);
                $user['securityAnswers'] = json_decode($user['securityAnswers'], true);
                echo json_encode($user);
            } else {
                http_response_code(404);
                echo json_encode(['message' => 'User not found']);
            }
        } else {
            // Fetch all records
            $sql = "SELECT * FROM User";
            $stmt = $pdo->query($sql);
            $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // Decode JSON fields for each user
            foreach ($users as &$user) {
                $user['securityQuestions'] = json_decode($user['securityQuestions'], true);
                $user['securityAnswers'] = json_decode($user['securityAnswers'], true);
            }

            echo json_encode($users);
        }
        break;

    case 'PUT':
        // Update an existing User
        $data = json_decode(file_get_contents('php://input'), true);
        $id = $data['id'] ?? null;
        $username = $data['username'] ?? null;
        $password = $data['password'] ?? null;
        $role = $data['role'] ?? null;
        $securityQuestions = $data['securityQuestions'] ?? null;
        $securityAnswers = $data['securityAnswers'] ?? null;
        $phone = $data['phone'] ?? null;
        $termId = $data['termId'] ?? null;

        if (!$id || !$username || !$password || !$role || !$securityQuestions || !$securityAnswers || !$phone) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid input']);
            exit;
        }

        $sql = "UPDATE User SET username = :username, password = :password, role = :role, securityQuestions = :securityQuestions, securityAnswers = :securityAnswers, phone = :phone, termId = :termId WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $id,
            ':username' => $username,
            ':password' => $password,
            ':role' => $role,
            ':securityQuestions' => json_encode($securityQuestions),
            ':securityAnswers' => json_encode($securityAnswers),
            ':phone' => $phone,
            ':termId' => $termId
        ]);

        echo json_encode(['message' => 'User updated successfully']);
        break;

    case 'DELETE':
        // Delete a specific User
        $id = $_GET['id'] ?? null;

        if (!$id) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid ID']);
            exit;
        }

        $sql = "DELETE FROM User WHERE id = :id";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $id]);

        if ($stmt->rowCount()) {
            echo json_encode(['message' => 'User deleted successfully']);
        } else {
            http_response_code(404);
            echo json_encode(['message' => 'User not found']);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        break;
}
?>
