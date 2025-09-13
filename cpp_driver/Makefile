CXX = g++
CXXFLAGS = -std=c++17 -O3 -march=native
TARGET = driver
SOURCE = driver.cpp

$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SOURCE)

clean:
	rm -f $(TARGET)

.PHONY: clean