module words;

import benchmark;
import helper;
import std::io;
import std::collections::map;

struct WordsData
{
	long words;
	long word_len;
	char* text;
	usz text_size;
	uint checksum_val;
}

fn void words_data_init(WordsData* data)
{
	data.words = helper::helper_config_i64("Etc::Words", "words");
	data.word_len = helper::helper_config_i64("Etc::Words", "word_len");
}

fn void words_prepare(Benchmark* self)
{
	WordsData* data = (WordsData*)self.data;

	free(data.text);
	data.text = null;

	String chars   = "abcdefghijklmnopqrstuvwxyz";
	int char_count = 26;

	char** words_array = mem::new_array(char*, (usz)data.words);
	sz total_len       = 0;

	for (int i = 0; i < (int)data.words; i++)
	{
		int len    = (int)helper::helper_next_int((uint)data.word_len) + (int)helper::helper_next_int(3) + 3;
		char* word = mem::new_array(char, (usz)(len + 1));
		for (int j = 0; j < len; j++)
		{
			int idx = (int)helper::helper_next_int((uint)char_count);
			word[j] = chars[idx];
		}
		word[len] = 0;
		words_array[i] = word;
		total_len += (sz)len + 1;
	}

	char* buffer = mem::new_array(char, total_len + 1);
	sz pos       = 0;
	for (int i = 0; i < (int)data.words; i++)
	{
		sz word_len = ((ZString)words_array[i]).len();
		mem::copy(buffer + pos, words_array[i], word_len);
		pos += word_len;
		if (i < data.words - 1)
		{
			buffer[pos++] = ' ';
		}
		free(words_array[i]);
	}
	buffer[pos] = 0;
	free(words_array);

	data.text = buffer;
	data.text_size = (usz)pos;
}

fn void words_run(Benchmark* self, int iteration_id)
{
	WordsData* data = (WordsData*)self.data;

	HashMap{String, int} frequencies;
	frequencies.init(mem);

	String text_str   = ((ZString)data.text).str_view();
	Splitter splitter = text_str.tokenize(" ");

	while (try word = splitter.next())
	{
		if (word.len >= 3)
		{
			*frequencies.get_or_create_ref(word) += 1;
		}
	}

	String max_word = "";
	int max_count   = 0;
	int freq_size   = 0;

	frequencies.@each_entry(; Entry{String, int}* e)
	{
		freq_size++;
		if (e.value > max_count)
		{
			max_count = e.value;
			max_word = e.key;
		}
	};

	uint word_checksum = helper::helper_checksum_string(max_word);
	data.checksum_val += (uint)max_count + word_checksum + (uint)freq_size;

	frequencies.free();
}

fn uint words_checksum(Benchmark* self)
{
	WordsData* data = (WordsData*)self.data;
	return data.checksum_val;
}

fn void words_cleanup(Benchmark* self)
{
	WordsData* data = (WordsData*)self.data;
	free(data.text);
	data.text = null;
	data.text_size = 0;
}

fn Benchmark* words_create() @cname("Words_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::Words");

	WordsData* data = mem::new(WordsData);
	words_data_init(data);

	bench.data = data;
	bench.prepare = (PrepareFn)&words_prepare;
	bench.run = (RunFn)&words_run;
	bench.checksum = (ChecksumFn)&words_checksum;
	bench.cleanup = (CleanupFn)&words_cleanup;

	return bench;
}