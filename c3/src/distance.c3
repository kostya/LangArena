module distance_bench;

import benchmark;
import helper;
import std::io;
import std::collections::map;

struct StringPairs
{
	String[] s1;
	String[] s2;
}

fn StringPairs* generate_pair_strings(long n, long m)
{
	StringPairs* pairs = mem::new(StringPairs);
	pairs.s1 = mem::new_array(String, (usz)n);
	pairs.s2 = mem::new_array(String, (usz)n);

	for (long i = 0; i < n; i++)
	{
		int len1 = (int)helper::helper_next_int((uint)m) + 4;
		int len2 = (int)helper::helper_next_int((uint)m) + 4;

		String s1 = (String)mem::new_array(char, (usz)len1);
		String s2 = (String)mem::new_array(char, (usz)len2);

		for (int j = 0; j < len1; j++)
		{
			s1[j] = (char)('a' + helper::helper_next_int(10));
		}

		for (int j = 0; j < len2; j++)
		{
			s2[j] = (char)('a' + helper::helper_next_int(10));
		}

		pairs.s1[i] = s1;
		pairs.s2[i] = s2;
	}

	return pairs;
}

fn void free_string_pairs(StringPairs* pairs)
{
	if (!pairs) return;

	for (usz i = 0; i < pairs.s1.len; i++)
	{
		free(pairs.s1[i]);
		free(pairs.s2[i]);
	}
	free(pairs.s1);
	free(pairs.s2);
	free(pairs);
}

struct JaroData
{
	StringPairs* pairs;
	uint result;
	long count;
	long size;
}

fn void jaro_prepare(Benchmark* self)
{
	JaroData* data = (JaroData*)self.data;

	data.count = helper::helper_config_i64(self.name, "count");
	data.size = helper::helper_config_i64(self.name, "size");

	data.pairs = generate_pair_strings(data.count, data.size);
}

fn double jaro_calc(String s1, String s2)
{
	sz len1 = s1.len;
	sz len2 = s2.len;

	if (len1 == 0 || len2 == 0) return 0.0;

	sz match_dist = (sz)((len1 > len2 ? len1 : len2) / 2) - 1;
	if (match_dist < 0) match_dist = 0;

	bool[] s1_matches = mem::new_array(bool, len1);
	bool[] s2_matches = mem::new_array(bool, len2);

	int matches = 0;
	for (sz i = 0; i < len1; i++)
	{
		sz start = i > match_dist ? i - match_dist : 0;
		sz end   = (len2 - 1 < i + match_dist) ? len2 - 1 : i + match_dist;

		for (sz j = start; j <= end; j++)
		{
			if (!s2_matches[j] && s1[i] == s2[j])
			{
				s1_matches[i] = true;
				s2_matches[j] = true;
				matches++;
				break;
			}
		}
	}

	double result = 0.0;

	if (matches > 0)
	{
		int transpositions = 0;
		sz k               = 0;

		for (sz i = 0; i < len1; i++)
		{
			if (s1_matches[i])
			{
				while (k < len2 && !s2_matches[k]) k++;
				if (k < len2)
				{
					if (s1[i] != s2[k]) transpositions++;
					k++;
				}
			}
		}
		transpositions /= 2;

		double m = (double)matches;
		result = (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
	}

	free(s1_matches);
	free(s2_matches);

	return result;
}

fn void jaro_run(Benchmark* self, int iteration_id)
{
	JaroData* data     = (JaroData*)self.data;
	StringPairs* pairs = data.pairs;

	for (usz i = 0; i < pairs.s1.len; i++)
	{
		double jaro = jaro_calc(pairs.s1[i], pairs.s2[i]);
		data.result += (uint)(jaro * 1000);
	}
}

fn uint jaro_checksum(Benchmark* self)
{
	JaroData* data = (JaroData*)self.data;
	return data.result;
}

fn void jaro_cleanup(Benchmark* self)
{
	JaroData* data = (JaroData*)self.data;
	if (data.pairs)
	{
		free_string_pairs(data.pairs);
		data.pairs = null;
	}
}

fn Benchmark* jaro_create() @cname("Jaro_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Distance::Jaro");
	JaroData* data   = mem::new(JaroData);

	bench.data = data;
	bench.prepare = (PrepareFn)&jaro_prepare;
	bench.run = (RunFn)&jaro_run;
	bench.checksum = (ChecksumFn)&jaro_checksum;
	bench.cleanup = (CleanupFn)&jaro_cleanup;

	return bench;
}

alias GramMap = HashMap{uint, int};

struct NGramData
{
	StringPairs* pairs;
	uint result;
	long count;
	long size;
}

fn void ngram_prepare(Benchmark* self)
{
	NGramData* data = (NGramData*)self.data;

	data.count = helper::helper_config_i64(self.name, "count");
	data.size = helper::helper_config_i64(self.name, "size");

	data.pairs = generate_pair_strings(data.count, data.size);
}

fn double ngram_calc(String s1, String s2)
{
	usz len1 = s1.len;
	usz len2 = s2.len;

	if (len1 < 4 || len2 < 4) return 0.0;

	GramMap grams1;
	grams1.init(mem);

	for (usz i = 0; i <= len1 - 4; i++)
	{
		uint gram = ((uint)s1[i] << 24) | ((uint)s1[i + 1] << 16) | ((uint)s1[i + 2] << 8) | (uint)s1[i + 3];

		*grams1.get_or_create_ref(gram) += 1;
	}

	GramMap grams2;
	grams2.init(mem);
	int intersection = 0;

	for (usz i = 0; i <= len2 - 4; i++)
	{
		uint gram = ((uint)s2[i] << 24) | ((uint)s2[i + 1] << 16) | ((uint)s2[i + 2] << 8) | (uint)s2[i + 3];

		*grams2.get_or_create_ref(gram) += 1;

		if (try g1 = grams1.get(gram))
		{
			if (try g2 = grams2.get(gram))
			{
				if (g2 <= g1) intersection++;
			}
		}
	}

	int total = (int)grams1.len() + (int)grams2.len();

	grams1.free();
	grams2.free();

	return total > 0 ? (double)intersection / total : 0.0;
}

fn void ngram_run(Benchmark* self, int iteration_id)
{
	NGramData* data    = (NGramData*)self.data;
	StringPairs* pairs = data.pairs;

	for (usz i = 0; i < pairs.s1.len; i++)
	{
		double sim = ngram_calc(pairs.s1[i], pairs.s2[i]);
		data.result += (uint)(sim * 1000);
	}
}

fn uint ngram_checksum(Benchmark* self)
{
	NGramData* data = (NGramData*)self.data;
	return data.result;
}

fn void ngram_cleanup(Benchmark* self)
{
	NGramData* data = (NGramData*)self.data;
	if (data.pairs)
	{
		free_string_pairs(data.pairs);
		data.pairs = null;
	}
}

fn Benchmark* ngram_create() @cname("NGram_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Distance::NGram");
	NGramData* data  = mem::new(NGramData);

	bench.data = data;
	bench.prepare = (PrepareFn)&ngram_prepare;
	bench.run = (RunFn)&ngram_run;
	bench.checksum = (ChecksumFn)&ngram_checksum;
	bench.cleanup = (CleanupFn)&ngram_cleanup;

	return bench;
}