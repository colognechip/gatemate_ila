def check_sequential_numbers(file_path):
    with open(file_path, 'r') as file:
        numbers = []
        
        # Lies die Datei zeilenweise ein
        for line in file:
            stripped_line = line.strip()
            
            # Überprüfe, ob die Zeile eine Zahl enthält
            if stripped_line.isdigit():
                numbers.append(int(stripped_line))
        
        # Überprüfe, ob die Zahlen fortlaufend sind
        for i in range(1, len(numbers)):
            if numbers[i] != numbers[i - 1] + 1:
                print(f"Die Zahlen sind nicht fortlaufend an Position {i}: {numbers[i-1]} gefolgt von {numbers[i]}")
        
        print("Alle Zahlen sind fortlaufend.")

# Beispiel-Nutzung:
file_path = 'test_15_10_2024'  # Pfad zu deiner Datei
check_sequential_numbers(file_path)