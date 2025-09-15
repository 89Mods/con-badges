import java.io.*;

public class ToConstArray {
	public static void main(String[] args) {
		try {
			FileInputStream fis = new FileInputStream(args[0]);
			int len = 0;
			System.out.print("const uint32_t pgm[] = {");
			while(fis.available() > 0) {
				if(len % 16 == 0) {
					System.out.println();
					System.out.print("\t");
				}
				len++;
				int val = fis.read();
				val |= fis.read() << 8;
				val |= fis.read() << 16;
				val |= fis.read() << 24;
				System.out.print(String.format("0x%08x,", val));
			}
			System.out.println();
			System.out.println("\t'C','h','i','r','p','!'");
			len += 6;
			System.out.println("};");
			System.out.println("const uint32_t pgm_len = " + len + ";");
			fis.close();
		}catch(Exception e) {
			e.printStackTrace();
		}
	}
}
