import random
import string

def generate_password(length):
    # Create a set of characters to use in the password
    characters = string.ascii_letters + string.digits + "!@#$%^&*()_+-=[]{};:,.<>/?|"

    # create a random password
    password = "".join(random.choice(characters) for i in range(length))

    # Output the password to the command line

    print("Password: " + password)

if __name__ == "__main__":

    # Generate a password with a random length between 12 and 16 characters

    length = random.randint(12, 16)

    print("Random Password Genreator")
    print("")
    generate_password(length)
