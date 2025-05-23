MAIN = main
ASSEMBLY = library
TARGET = main

all: $(ASSEMBLY).o $(MAIN).o $(TARGET)
	@echo "Compilation complete"

$(ASSEMBLY).o: $(ASSEMBLY).s
	as -o $(ASSEMBLY).o $(ASSEMBLY).s

$(MAIN).o: $(MAIN).c hps_0.h
	gcc -c -o $(MAIN).o $(MAIN).c

$(TARGET): $(ASSEMBLY).o $(MAIN).o
	gcc -o $(TARGET) $(ASSEMBLY).o $(MAIN).o

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f *.o $(TARGET)

debug: $(TARGET)
	gdb $(TARGET)