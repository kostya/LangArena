#include "mandelbrot.hpp"
#include <sstream>

Mandelbrot::Mandelbrot() {
  w = config_val("w");
  h = config_val("h");
}

std::string Mandelbrot::name() const { return "CLBG::Mandelbrot"; }

void Mandelbrot::run(int iteration_id) {
  (void)iteration_id;
  std::ostringstream header;
  header << "P4\n" << w << " " << h << "\n";
  std::string header_str = header.str();
  result_bin.insert(result_bin.end(), header_str.begin(), header_str.end());

  int bit_num = 0;
  uint8_t byte_acc = 0;

  for (int y = 0; y < h; y++) {
    double ci = 2.0 * static_cast<double>(y) / static_cast<double>(h) - 1.0;
    for (int x = 0; x < w; x++) {
      double cr = 2.0 * static_cast<double>(x) / static_cast<double>(w) - 1.5;

      double zr = 0.0, zi = 0.0;
      double tr = 0.0, ti = 0.0;

      int i = 0;
      while (i < ITER && tr + ti <= LIMIT * LIMIT) {
        zi = 2.0 * zr * zi + ci;
        zr = tr - ti + cr;
        tr = zr * zr;
        ti = zi * zi;
        i++;
      }

      byte_acc <<= 1;
      if (tr + ti <= LIMIT * LIMIT) {
        byte_acc |= 0x01;
      }
      bit_num++;

      if (bit_num == 8) {
        result_bin.push_back(byte_acc);
        byte_acc = 0;
        bit_num = 0;
      } else if (x == w - 1) {
        byte_acc <<= (8 - (w % 8));
        result_bin.push_back(byte_acc);
        byte_acc = 0;
        bit_num = 0;
      }
    }
  }
}

uint32_t Mandelbrot::checksum() { return Helper::checksum(result_bin); }